// The app's WorkdayRepository against a real Odoo 19. Runs whichever work-day
// store that server has: the dedicated `/api/workday/*` routes when
// `dh_workday_tracking` is installed, otherwise the `x_dh_work_*` models the
// repository falls back to. The assertions that only the module can make (its
// server-side validation) are skipped on the fallback, because a no-code model
// has no constraints to enforce them. Skipped entirely unless pointed at a
// server:
//
//   WORKDAY_IT_URL=http://localhost:18069 WORKDAY_IT_DB=wd_test \
//   WORKDAY_IT_LOGIN=it_emp WORKDAY_IT_PASSWORD=... \
//   flutter test test/workday_odoo_integration_test.dart
//
// Never run it against a production database: it opens and closes work days
// for the given user.
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/core/api/api_client.dart';
import 'package:location_gps/core/api/api_exceptions.dart';
import 'package:location_gps/core/api/endpoints.dart';
import 'package:location_gps/features/visits/data/models/visit_location_log.dart';
import 'package:location_gps/features/workday/data/models/workday_models.dart';
import 'package:location_gps/features/workday/data/workday_repository.dart';

void main() {
  final env = Platform.environment;
  final url = env['WORKDAY_IT_URL'];
  final skip = url == null ? 'set WORKDAY_IT_URL to run against a real Odoo' : false;

  test('WorkdayRepository speaks the real work-day contract', () async {
    final jar = PersistCookieJar(storage: FileStorage(Directory.systemTemp.createTempSync('wd_it').path));
    final api = ApiClient(cookieJar: jar, baseUrl: url!);
    final session = await api.jsonRpc(Endpoints.authenticate, params: {
      'db': env['WORKDAY_IT_DB'],
      'login': env['WORKDAY_IT_LOGIN'],
      'password': env['WORKDAY_IT_PASSWORD'],
    });
    // The signed-in uid. The `/api/workday/*` routes derive the employee from
    // the session and ignore it, but the fallback models are filtered by
    // `create_uid`, so a wrong uid there silently finds nothing — which used
    // to leave a stale open day behind and fail every later run.
    final userId = ((session as Map)['uid'] as num).toInt();
    final repo = WorkdayRepository(api: api);
    final backend = await repo.backend();
    // ignore: avoid_print
    print('work-day store on this server: ${backend.name}');
    final dedicated = backend == WorkdayBackend.api;
    expect(await repo.isSupported(), isTrue);

    final open = await repo.activeSession(userId);
    if (open != null) await repo.completeSession(open.id, endedAt: DateTime.now().toUtc());
    expect(await repo.activeSession(userId), isNull);

    final uid = 'wd-it-${DateTime.now().millisecondsSinceEpoch}';
    final started = DateTime.now().toUtc();
    final id = await repo.createSession(clientUid: uid, startedAt: started, latitude: 24.716873, longitude: 46.683047);
    if (dedicated) {
      // `/api/workday/start` is idempotent server-side. The fallback models
      // have no such route, so `WorkdayTracker` gets the same guarantee by
      // looking the day up (by client uid, then by open day) before it ever
      // calls this — which is what the two lookups below stand in for here.
      expect(await repo.createSession(clientUid: uid, startedAt: started), id, reason: 'idempotent');
      expect(await repo.createSession(clientUid: '$uid-other-phone', startedAt: started), id,
          reason: 'the open day is returned, never a second one');
    }
    expect((await repo.sessionByClientUid(uid))!.id, id,
        reason: 'a retried Start finds the day it already opened');
    expect((await repo.activeSession(userId))!.id, id);

    WorkdayPoint point(int i, double lat, {WorkdayPointSource source = WorkdayPointSource.track}) => WorkdayPoint(
          uid: '$uid-$i',
          sessionUid: uid,
          source: source,
          point: TrailPoint(
            latitude: lat,
            longitude: 46.683 + i * 0.0003,
            loggedAt: DateTime.now().toUtc(),
            accuracy: 6,
            speed: 8,
            heading: 90,
            deviceId: 'integration-test',
          ),
        );
    final batch = [point(0, 24.7168, source: WorkdayPointSource.start), point(1, 24.7170), point(2, 24.7172)];
    await repo.createPoints(id, points: batch);
    if (dedicated) {
      // The module's unique index on (session, client uid) makes a re-sent
      // batch harmless server-side.
      await repo.createPoints(id, points: batch);
    } else {
      // The fallback models have no such index, so `WorkdayTracker` asks which
      // uids the server already holds and drops them before re-sending. Same
      // outcome, decided one round trip earlier.
      expect(
        await repo.existingPointUids([for (final p in batch) p.uid]),
        {for (final p in batch) p.uid},
      );
    }

    if (dedicated) {
      // Only the module validates a point; the fallback models cannot.
      await expectLater(
        repo.createPoints(id, points: [point(3, 24.7174), point(4, 999)]),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.validation)
            .having((e) => e.serverMessage, 'message', contains('out of range'))),
      );
    } else {
      await repo.createPoints(id, points: [point(3, 24.7174)]);
    }

    final sessions = await repo.sessionsForDay(userId, DateTime.now());
    final mine = sessions.firstWhere((s) => s.id == id);
    final route = await repo.readRoute(mine);
    expect(route.logs.map((l) => l.latitude), [24.7168, 24.7170, 24.7172, 24.7174]);
    expect(route.logs.first.isStart, isTrue);
    expect(route.logs.map((l) => l.accuracy), everyElement(6.0));

    await repo.completeSession(id, endedAt: DateTime.now().toUtc(), latitude: 24.7176, longitude: 46.6845);
    await repo.completeSession(id, endedAt: DateTime.now().toUtc()); // retried end
    expect((await repo.readSession(id))!.state, WorkSessionState.completed);
    if (dedicated) {
      // A closed day refuses new points — again, only the module enforces it.
      await expectLater(
        repo.createPoints(id, points: [point(5, 24.7178)]),
        throwsA(isA<ApiException>().having((e) => e.odooName, 'odooName', 'odoo.exceptions.UserError')),
      );
    }
  }, skip: skip);
}
