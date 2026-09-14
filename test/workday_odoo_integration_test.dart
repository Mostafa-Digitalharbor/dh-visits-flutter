// The app's WorkdayRepository against a real Odoo 19 running
// dh_workday_tracking. Skipped unless pointed at one:
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

  test('WorkdayRepository speaks the real /api/workday/* contract', () async {
    final jar = PersistCookieJar(storage: FileStorage(Directory.systemTemp.createTempSync('wd_it').path));
    final api = ApiClient(cookieJar: jar, baseUrl: url!);
    await api.jsonRpc(Endpoints.authenticate, params: {
      'db': env['WORKDAY_IT_DB'],
      'login': env['WORKDAY_IT_LOGIN'],
      'password': env['WORKDAY_IT_PASSWORD'],
    });
    final repo = WorkdayRepository(api: api);
    expect(await repo.backend(), WorkdayBackend.api);
    expect(await repo.isSupported(), isTrue);

    final open = await repo.activeSession(0);
    if (open != null) await repo.completeSession(open.id, endedAt: DateTime.now().toUtc());
    expect(await repo.activeSession(0), isNull);

    final uid = 'wd-it-${DateTime.now().millisecondsSinceEpoch}';
    final started = DateTime.now().toUtc();
    final id = await repo.createSession(clientUid: uid, startedAt: started, latitude: 24.716873, longitude: 46.683047);
    expect(await repo.createSession(clientUid: uid, startedAt: started), id, reason: 'idempotent');
    expect(await repo.createSession(clientUid: '$uid-other-phone', startedAt: started), id,
        reason: 'the open day is returned, never a second one');
    expect((await repo.sessionByClientUid(uid))!.id, id);
    expect((await repo.activeSession(0))!.id, id);

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
    await repo.createPoints(id, points: batch); // a re-sent batch is harmless

    await expectLater(
      repo.createPoints(id, points: [point(3, 24.7174), point(4, 999)]),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', ApiErrorCode.validation)
          .having((e) => e.serverMessage, 'message', contains('out of range'))),
    );

    final sessions = await repo.sessionsForDay(0, DateTime.now());
    final mine = sessions.firstWhere((s) => s.id == id);
    final route = await repo.readRoute(mine);
    expect(route.logs.map((l) => l.latitude), [24.7168, 24.7170, 24.7172, 24.7174]);
    expect(route.logs.first.isStart, isTrue);
    expect(route.logs.map((l) => l.accuracy), everyElement(6.0));

    await repo.completeSession(id, endedAt: DateTime.now().toUtc(), latitude: 24.7176, longitude: 46.6845);
    await repo.completeSession(id, endedAt: DateTime.now().toUtc()); // retried end
    expect((await repo.readSession(id))!.state, WorkSessionState.completed);
    await expectLater(
      repo.createPoints(id, points: [point(5, 24.7178)]),
      throwsA(isA<ApiException>().having((e) => e.odooName, 'odooName', 'odoo.exceptions.UserError')),
    );
  }, skip: skip);
}
