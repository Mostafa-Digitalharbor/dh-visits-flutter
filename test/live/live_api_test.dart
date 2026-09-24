// Every repository the app ships, driven against a real Odoo — the app's own
// request builders and parsers, not a re-implementation of them. Skipped unless
// pointed at a server:
//
//   LIVE_ODOO_URL=https://visits-dhh.odoo.com LIVE_ODOO_DB=<db> \
//   LIVE_ODOO_LOGIN=<login> LIVE_ODOO_PASSWORD=<password> \
//   flutter test test/live/live_api_test.dart
//
// The account needs the visit *admin* role (it plays both the rep and the
// approving manager). The run creates visits, trail points and attachments,
// all tagged with [_qaTag] in their purpose, and cancels what the workflow
// allows it to. Never point it at a database real reps use.
//
// The "visit GPS contract" group drives the app's own VisitTrailTracker (with
// a scripted native capture in place of the GPS hardware) against the server
// and reads the result back through /api/visit/track: recording only while
// the visit is in progress, nothing after End, late offline uploads inside
// the window accepted, and no point crossing from one visit to another.
//
// Each failure is also rendered through the app's own error localization, in
// both languages, so the run proves what a user would actually read — not just
// that an exception of the right class came back.
//
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:location_gps/core/api/api_client.dart';
import 'package:location_gps/core/api/api_error_messages.dart';
import 'package:location_gps/core/api/api_exceptions.dart';
import 'package:location_gps/core/api/endpoints.dart';
import 'package:location_gps/core/config/server_config.dart';
import 'package:location_gps/core/config/server_config_repository.dart';
import 'package:location_gps/core/location/location_service.dart';
import 'package:location_gps/core/location/journal_entry.dart';
import 'package:location_gps/core/location/visit_location_channel.dart';
import 'package:location_gps/core/network/connectivity_status.dart';
import 'package:location_gps/core/network/server_clock.dart';
import 'package:location_gps/core/push/push_repository.dart';
import 'package:location_gps/core/storage/session_storage.dart';
import 'package:location_gps/features/auth/data/auth_repository.dart';
import 'package:location_gps/features/auth/data/models/user.dart';
import 'package:location_gps/features/customers/data/customers_repository.dart';
import 'package:location_gps/features/employees/data/employees_repository.dart';
import 'package:location_gps/features/visits/data/models/visit.dart';
import 'package:location_gps/features/visits/data/models/visit_location_log.dart';
import 'package:location_gps/features/visits/data/models/visit_participant.dart';
import 'package:location_gps/features/visits/data/visit_tracking_consent.dart';
import 'package:location_gps/features/visits/data/visit_trail_tracker.dart';
import 'package:location_gps/features/visits/data/visits_repository.dart';
import 'package:location_gps/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _qaTag = '[QA-AUTO]';

PersistCookieJar _tempJar() => PersistCookieJar(
      storage: FileStorage(Directory.systemTemp.createTempSync('live_api').path),
    );

final _env = Platform.environment;
final _url = _env['LIVE_ODOO_URL'];
final _db = _env['LIVE_ODOO_DB'];
final _login = _env['LIVE_ODOO_LOGIN'];
final _password = _env['LIVE_ODOO_PASSWORD'];

final Object _skip = (_url == null || _db == null || _login == null || _password == null)
    ? 'set LIVE_ODOO_URL / LIVE_ODOO_DB / LIVE_ODOO_LOGIN / LIVE_ODOO_PASSWORD to run'
    : false;

final _en = lookupAppLocalizations(const Locale('en'));
final _ar = lookupAppLocalizations(const Locale('ar'));

/// What a user would read for [e], in both languages. Also asserts neither
/// language leaks the other's script, which is the failure this whole path
/// exists to prevent.
String _userFacing(ApiException e) {
  final en = e.messageFor(_en);
  final ar = e.messageFor(_ar);
  expect(ar, isNot(matches(RegExp(r'[A-Za-z]{4,}'))),
      reason: 'Arabic message leaks English: $ar');
  return 'en="$en" | ar="$ar"';
}

Future<ApiException> _expectApiError(Future<Object?> Function() call) async {
  try {
    await call();
  } on ApiException catch (e) {
    return e;
  }
  fail('expected an ApiException');
}

void main() {
  // The widgets binding swaps in a mock HttpClient that answers 400 to
  // everything; this suite needs the real network.
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  late ApiClient api;
  late SessionStorage session;
  late AuthRepository auth;
  late VisitsRepository visits;
  late ServerClock clock;
  late SharedPreferences prefs;
  late AuthUser user;
  late PersistCookieJar jar;
  int? projectId;
  int? mainVisitId;

  setUpAll(() async {
    if (_skip != false) return;
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final serverConfig = ServerConfigRepository(prefs: prefs);
    await serverConfig.save(ServerConfig(baseUrl: _url!, database: _db));
    jar = _tempJar();
    clock = ServerClock();
    api = ApiClient(cookieJar: jar, baseUrl: _url!, serverClock: clock);
    session = SessionStorage();
    auth = AuthRepository(
      api: api,
      session: session,
      cookieJar: jar,
      serverConfig: serverConfig,
    );
    api.reauthenticate = auth.reauthenticate;
    visits = VisitsRepository(api: api, session: session, serverClock: clock);
  });

  group('auth', () {
    test('a wrong password is reported as invalid credentials', () async {
      final e = await _expectApiError(
          () => auth.login(login: _login!, password: 'wrong-on-purpose'));
      expect(e.code, ApiErrorCode.invalidCredentials);
      printOnFailure(_userFacing(e));
      print('  wrong password → ${_userFacing(e)}');
    });

    test('an unknown login is reported as invalid credentials', () async {
      final e = await _expectApiError(() =>
          auth.login(login: 'nobody-${DateTime.now().millisecondsSinceEpoch}', password: 'x'));
      expect(e.code, ApiErrorCode.invalidCredentials);
    });

    test('signs in and resolves role, employee and timezone', () async {
      user = await auth.login(login: _login!, password: _password!);
      print('  signed in: uid=${user.uid} role=${user.visitRole} '
          'employee=${user.employeeId} tz=${user.tz}');
      expect(user.uid, greaterThan(0));
      expect(user.profileIncomplete, isFalse);
      expect(user.visitRole, isNot(VisitRole.none));
      expect(await auth.currentUser(), isNotNull);
    });
  }, skip: _skip);

  group('reference data', () {
    test('customers list, search and detail', () async {
      final repo = CustomersRepository(api: api);
      final all = await repo.list();
      print('  customers: ${all.length}');
      expect(all, isNotEmpty);
      final byName = await repo.list(search: all.first.name.substring(0, 2));
      expect(byName, isNotEmpty);
      final detail = await repo.getById(all.first.id);
      expect(detail.id, all.first.id);
      expect(detail.name, all.first.name);
    });

    test('employees list and search', () async {
      final repo = EmployeesRepository(api: api);
      final all = await repo.list();
      print('  employees: ${all.length}, '
          'with hr employee: ${all.where((e) => e.hrEmployeeId != null).length}');
      expect(all, isNotEmpty);
      expect(await repo.list(search: all.first.name.substring(0, 2)), isNotEmpty);
    });

    test('project and opportunity pickers', () async {
      final projects = await visits.listProjects();
      print('  projects: ${projects.length}');
      expect(projects, isNotEmpty, reason: 'the workflow below needs a project');
      projectId = projects.first.id;
      // Visit groups may have no crm.lead access (docs/OPPORTUNITY_VISIT_ACCESS.md):
      // either a list or a permission error the UI can explain.
      try {
        print('  opportunities: ${(await visits.listOpportunities()).length}');
      } on ApiException catch (e) {
        expect(e.code, ApiErrorCode.permissionDenied);
        print('  opportunities denied → ${_userFacing(e)}');
      }
    });
  }, skip: _skip);

  group('visit lists', () {
    test('my visits parse', () async {
      final mine = await visits.myVisits(limit: 50);
      print('  my visits: ${mine.length} '
          '(${mine.map((v) => v.state.name).toSet().join(', ')})');
      for (final v in mine) {
        expect(v.id, greaterThan(0));
      }
    });

    test('every manager scope parses', () async {
      for (final scope in VisitManagerScope.values) {
        final rows = await visits.managerList(scope);
        print('  manager/${scope.name}: ${rows.length}');
      }
    });

    test('notification feed and badge count agree', () async {
      final feed = await visits.myActivities();
      final count = await visits.myActivityCount();
      print('  activities: ${feed.length}, count=$count');
      expect(count, greaterThanOrEqualTo(feed.length));
    });
  }, skip: _skip);

  group('visit workflow', () {
    test('create → get → full read', () async {
      final created = await visits.createVisit({
        'visit_type': 'project',
        'project_id': projectId,
        'scheduled_datetime': VisitsRepository.formatOdooUtc(
            DateTime.now().add(const Duration(hours: 1))),
        'purpose': '$_qaTag live API workflow',
        if (user.employeeId != null) 'employee_id': user.employeeId,
      });
      mainVisitId = created.id;
      print('  created visit ${created.id} (${created.state.name})');
      expect(created.state, VisitState.draft);

      final slim = await visits.getVisit(created.id);
      expect(slim?.id, created.id);
      final full = await visits.readVisitFull(created.id);
      expect(full?.purpose, contains(_qaTag));
      expect(full?.partnerId, isNotNull, reason: 'customer auto-fills from the project');
      final office = await visits.partnerLocation(full!.partnerId!);
      print('  customer office: ${office == null ? 'no coordinates' : '${office.latitude},${office.longitude}'}');
    });

    test('starting a draft is refused with a translated rule', () async {
      final e = await _expectApiError(() =>
          visits.start(mainVisitId!, latitude: 24.7136, longitude: 46.6753));
      print('  start draft → ${e.code.name}: ${_userFacing(e)}');
      expect(e.messageFor(_en), isNot(_en.errUnknown));
    });

    test('a visit without a purpose is refused with the field named', () async {
      final e = await _expectApiError(() => visits.createVisit({
            'visit_type': 'project',
            'project_id': projectId,
            'scheduled_datetime': VisitsRepository.formatOdooUtc(DateTime.now()),
          }));
      print('  missing purpose → ${e.code.name}: ${_userFacing(e)}');
      expect(e.messageFor(_en), isNot(_en.errUnknown));
    });

    test('submit → approve', () async {
      final submitted = await visits.submit(mainVisitId!);
      print('  submitted → $submitted');
      expect(submitted, isNotNull);
      try {
        final approved = await visits.approve(mainVisitId!);
        print('  approved → $approved');
      } on ApiException catch (e) {
        // An admin approving their own visit may be refused by the approval
        // rules; the message must still explain it.
        print('  approve refused → ${e.code.name}: ${_userFacing(e)}');
        expect(e.messageFor(_en), isNot(_en.errUnknown));
      }
      final after = await visits.readVisitFull(mainVisitId!);
      print('  state after approval: ${after?.state.name}');
    });

    test('start → trail → attachment → end', () async {
      final state = (await visits.readVisitFull(mainVisitId!))!.state;
      if (state != VisitState.approved) {
        markTestSkipped('visit is ${state.name}, not approved — the account cannot approve it');
        return;
      }
      final started = await visits.start(mainVisitId!,
          latitude: 24.7136, longitude: 46.6753, location: '$_qaTag start');
      expect(started.state, VisitState.inProgress);
      expect(started.at, isNotNull, reason: 'start_datetime is echoed');

      // A few seconds past the start: the server stores whole seconds and
      // refuses a point that predates start_datetime.
      await Future<void>.delayed(const Duration(seconds: 2));
      final now = clock.now().add(const Duration(seconds: 1));
      final flush = await visits.logLocations(mainVisitId!, [
        for (var i = 0; i < 5; i++)
          TrailPoint(
            latitude: 24.7136 + i * 0.0004,
            longitude: 46.6753 + i * 0.0004,
            loggedAt: now.add(Duration(seconds: i * 20)),
            accuracy: 8,
            speed: 6,
          ),
        // Out of range on purpose: refused on its own, by index.
        TrailPoint(latitude: 123, longitude: 46.6, loggedAt: now),
      ]);
      print('  trail batch: created=${flush.created} rejected='
          '${flush.rejected.map((r) => '#${r.index} ${r.error}').join('; ')}');
      expect(flush.created, 5);
      expect(flush.rejected.map((r) => r.index), [5]);

      final single = await visits.logLocation(mainVisitId!,
          latitude: 24.716, longitude: 46.678, accuracy: 5);
      expect(single, isNotNull);

      final track = await visits.readTrack(mainVisitId!);
      print('  track: ${track.logs.length} points, ${track.trackedDistanceKm} km');
      // The batch's 5, the single fix, plus the point the server records
      // itself from the start coordinates.
      expect(track.logs.length, greaterThanOrEqualTo(6));
      expect(track.locationLogCount, track.logs.length);
      final paged = await visits.readTrack(mainVisitId!, limit: 2, offset: 1);
      expect(paged.logs.length, 2);

      final attachmentId = await visits.uploadAttachment(mainVisitId!,
          filename: 'qa-auto.txt',
          dataB64: base64.encode(utf8.encode('$_qaTag attachment')));
      expect(attachmentId, isNotNull);
      final attachments = await visits.readAttachments(mainVisitId!);
      expect(attachments.map((a) => a.id), contains(attachmentId));
      final bytes = await visits.downloadAttachmentB64(attachmentId!);
      expect(utf8.decode(base64.decode(bytes!)), contains(_qaTag));

      final endNoOutcome = await _expectApiError(
          () => visits.end(mainVisitId!, outcome: '', latitude: 24.7, longitude: 46.6));
      print('  end without outcome → ${_userFacing(endNoOutcome)}');

      final ended = await visits.end(mainVisitId!,
          outcome: '$_qaTag done', latitude: 24.7140, longitude: 46.6760);
      expect(ended.state, VisitState.done);
      expect(ended.at, isNotNull, reason: 'end_datetime is echoed');
      expect(await visits.hasMockLocationFlag(mainVisitId!), isFalse);
    });

    test('reject → reschedule → cancel on a second visit', () async {
      final v = await visits.createVisit({
        'visit_type': 'project',
        'project_id': projectId,
        'scheduled_datetime': VisitsRepository.formatOdooUtc(
            DateTime.now().add(const Duration(hours: 2))),
        'purpose': '$_qaTag reject path',
      });
      await visits.submit(v.id);
      try {
        print('  rejected → ${await visits.reject(v.id, '$_qaTag rejecting on purpose')}');
        final res = await visits.reschedule(v.id,
            scheduledDatetime: DateTime.now().add(const Duration(days: 1)));
        print('  rescheduled → $res');
      } on ApiException catch (e) {
        print('  reject/reschedule refused → ${e.code.name}: ${_userFacing(e)}');
      }
      await visits.cancel(v.id);
      final after = await visits.readVisitFull(v.id);
      print('  after cancel: ${after?.state.name}');
      expect(after?.state, VisitState.cancelled);
    });

    test('participants: add, read, decide', () async {
      final v = await visits.createVisit({
        'visit_type': 'project',
        'project_id': projectId,
        'scheduled_datetime': VisitsRepository.formatOdooUtc(
            DateTime.now().add(const Duration(hours: 3))),
        'purpose': '$_qaTag participants',
      });
      final others = (await EmployeesRepository(api: api).list())
          .where((e) => e.hrEmployeeId != null && e.hrEmployeeId != user.employeeId)
          .map((e) => e.hrEmployeeId!)
          .take(1)
          .toList();
      final added = await visits.addParticipants(v.id, others);
      final lines = await visits.readParticipants(v.id);
      print('  participants: added=${added.length} read=${lines.length}');
      expect(lines.length, others.length);
      if (lines.isNotEmpty) {
        try {
          await visits.approveParticipant(lines.first.id);
          print('  participant approved');
        } on ApiException catch (e) {
          print('  participant approve refused → ${e.code.name}: ${_userFacing(e)}');
        }
      }
      await visits.cancel(v.id);
    });

    test('an unknown visit id is explained, not crashed on', () async {
      final e = await _expectApiError(() => visits.getVisit(999999999));
      print('  unknown visit → ${e.code.name}: ${_userFacing(e)}');
      expect(e.code, ApiErrorCode.notFound);
      expect(e.code, isNot(ApiErrorCode.unauthorized),
          reason: 'must never log the user out');
    });
  }, skip: _skip);

  group('visit GPS contract', () {
    /// A fresh visit taken through submit and approve, or null when this
    /// account may not approve it.
    Future<int?> approvedVisit(String label) async {
      final v = await visits.createVisit({
        'visit_type': 'project',
        'project_id': projectId,
        'scheduled_datetime': VisitsRepository.formatOdooUtc(
            DateTime.now().add(const Duration(hours: 1))),
        'purpose': '$_qaTag $label',
        if (user.employeeId != null) 'employee_id': user.employeeId,
      });
      await visits.submit(v.id);
      try {
        await visits.approve(v.id);
      } on ApiException catch (e) {
        print('  approve refused → ${_userFacing(e)}');
        return null;
      }
      final state = (await visits.getVisit(v.id))?.state;
      return state == VisitState.approved ? v.id : null;
    }

    VisitTrailTracker trackerFor(
      _ScriptedCapture capture,
      ConnectivityStatus connectivity,
    ) =>
        VisitTrailTracker(
          prefs: prefs,
          repository: visits,
          locationService: _Permitted(),
          connectivity: connectivity,
          notificationLabels: () => (title: _en.visitTrackingNotificationTitle, text: _en.visitTrackingNotificationText),
          channel: capture,
          serverClock: clock,
        );

    Future<void> pause(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

    test('no point is accepted before Start', () async {
      final id = await approvedVisit('no tracking before start');
      if (id == null) return markTestSkipped('account cannot approve');
      try {
        final r = await visits.logLocations(id, [
          TrailPoint(latitude: 24.7, longitude: 46.6, loggedAt: clock.now()),
        ]);
        print('  before start: created=${r.created} rejected=${r.rejected.map((e) => e.error)}');
        expect(r.created, 0);
      } on ApiException catch (e) {
        print('  before start → ${e.code.name}: ${_userFacing(e)}');
      }
      expect((await visits.readTrack(id)).logs, isEmpty);
      await visits.cancel(id);
    });

    test('every coordinate field reaches the server exactly as sent, '
        'even with the app in Arabic', () async {
      final id = await approvedVisit('coordinate round-trip');
      if (id == null) return markTestSkipped('account cannot approve');
      // An Arabic UI switches intl to Arabic-Indic digits; the wire formats
      // must not follow it.
      await initializeDateFormatting('ar');
      final previousLocale = Intl.defaultLocale;
      Intl.defaultLocale = 'ar';
      addTearDown(() => Intl.defaultLocale = previousLocale);

      const startLat = 24.7136123, startLng = 46.6753456;
      const endLat = 24.7742789, endLng = 46.7386012;
      final started = await visits.start(id,
          latitude: startLat, longitude: startLng, location: '$_qaTag gate');
      expect(started.state, VisitState.inProgress);
      await pause(2500);

      // Whole seconds: the server stores fix times to the second.
      DateTime second(DateTime t) =>
          DateTime.utc(t.year, t.month, t.day, t.hour, t.minute, t.second);
      final t1 = second(clock.now().subtract(const Duration(seconds: 1)));
      final t2 = second(clock.now());
      const deviceId = 'qa-auto-device';
      final sent = [
        // Sent newest first on purpose: the server files by fix time.
        TrailPoint(
          latitude: 24.7200987, longitude: 46.6900654, loggedAt: t2,
          accuracy: 4.25, altitude: 611.5, speed: 13.75, heading: 270.5,
          deviceId: deviceId,
        ),
        TrailPoint(
          latitude: 24.7150321, longitude: 46.6800123, loggedAt: t1,
          accuracy: 7.5, altitude: 612.25, speed: 12.5, heading: 41.0,
          deviceId: deviceId,
        ),
      ];
      final flush = await visits.logLocations(id, sent);
      expect(flush.created, 2);
      expect(flush.rejected, isEmpty);

      await pause(1500);
      final single = await visits.logLocation(id,
          latitude: 24.7300555, longitude: 46.7000444,
          accuracy: 3.0, speed: 0.0, heading: 0.0, altitude: 600.0,
          deviceId: deviceId);
      expect(single, isNotNull);

      await pause(1200);
      final ended = await visits.end(id,
          outcome: '$_qaTag done', latitude: endLat, longitude: endLng,
          location: '$_qaTag lobby');
      expect(ended.state, VisitState.done);

      final logs = (await visits.readTrack(id)).logs;
      print('  round-trip trail: ${[
        for (final l in logs)
          '${l.source.name}(${l.latitude},${l.longitude} '
              'acc=${l.accuracy} alt=${l.altitude} spd=${l.speed} hdg=${l.heading} '
              'at=${l.loggedAt.toIso8601String()})'
      ].join(' → ')}');
      expect(logs.map((l) => l.source).toList(), [
        TrailSource.start,
        TrailSource.track,
        TrailSource.track,
        TrailSource.track,
        TrailSource.end,
      ]);

      void same(VisitLocationLog got, TrailPoint want) {
        expect(got.latitude, want.latitude);
        expect(got.longitude, want.longitude);
        expect(got.loggedAt, want.loggedAt);
        expect(got.accuracy, want.accuracy);
        expect(got.altitude, want.altitude);
        expect(got.speed, want.speed);
        expect(got.heading, want.heading);
        expect(got.deviceId, want.deviceId);
      }

      expect((logs.first.latitude, logs.first.longitude), (startLat, startLng));
      same(logs[1], sent[1]);
      same(logs[2], sent[0]);
      expect((logs[3].latitude, logs[3].longitude), (24.7300555, 46.7000444));
      expect(logs[3].accuracy, 3.0);
      expect(logs[3].deviceId, deviceId);
      expect((logs.last.latitude, logs.last.longitude), (endLat, endLng));

      // The visit record keeps the start/end fixes too.
      final full = await visits.readVisitFull(id);
      print('  visit record: start=(${full?.startLat},${full?.startLng}) '
          'end=(${full?.endLat},${full?.endLng})');
      expect((full?.startLat, full?.startLng), (startLat, startLng));
      expect((full?.endLat, full?.endLng), (endLat, endLng));
      // The trail counters come with the REST payload and the track read
      // (the full call_kw read deliberately leaves them out).
      final slim = await visits.getVisit(id);
      final track = await visits.readTrack(id);
      expect(slim?.locationLogCount, 5);
      expect(track.locationLogCount, 5);
      expect(slim!.trackedDistanceKm, greaterThan(0));
      expect(track.trackedDistanceKm, slim.trackedDistanceKm);
    });

    test('the tracker records only between Start and End; dead-zone points '
        'land after End in their place', () async {
      final id = await approvedVisit('tracker lifecycle');
      if (id == null) return markTestSkipped('account cannot approve');
      await VisitTrackingConsent(prefs).accept();
      final capture = _ScriptedCapture();
      final connectivity = ConnectivityStatus();
      final tracker = trackerFor(capture, connectivity);

      // Approved, not started: the phone moves, nothing is captured.
      capture.move(id, DateTime.now().toUtc(), 24.6990, 46.5990);
      expect(capture.starts, isEmpty);
      expect(capture.journal, isEmpty);

      final started = await visits.start(id,
          latitude: 24.7000, longitude: 46.6000, location: '$_qaTag start');
      expect(started.state, VisitState.inProgress);
      await tracker.start(id,
          startedAt: started.at, seedLatitude: 24.7, seedLongitude: 46.6);
      expect(capture.active, isTrue);

      // Foreground movement, uploaded.
      await pause(3500);
      for (var i = 1; i <= 3; i++) {
        capture.move(id, DateTime.now().toUtc(), 24.7000 + i * 0.0006, 46.6000 + i * 0.0006);
        await pause(300);
      }
      await tracker.drain();
      await tracker.flushNow();
      var track = await visits.readTrack(id);
      final online = track.logs.where((l) => l.source == TrailSource.track).length;
      print('  after online movement: ${track.logs.length} points ($online track)');
      expect(online, 3);

      // Dead zone: two fixes kept on the device.
      connectivity.markOffline();
      for (var i = 4; i <= 5; i++) {
        capture.move(id, DateTime.now().toUtc(), 24.7000 + i * 0.0006, 46.6000 + i * 0.0006);
        await pause(300);
      }
      await tracker.drain();
      await tracker.flushNow();
      expect(tracker.pendingCount.value, 2, reason: 'offline — kept, not sent');

      // End: capture stops before the request.
      await tracker.stop(flush: false);
      expect(capture.active, isFalse);
      await pause(1200);
      final ended = await visits.end(id,
          outcome: '$_qaTag done', latitude: 24.7040, longitude: 46.6040);
      expect(ended.state, VisitState.done);

      // Movement after End: the capture records nothing, and a fix that
      // would still reach the journal is discarded on the Dart side.
      capture.move(id, DateTime.now().toUtc(), 24.8, 46.8);
      capture.inject(id, DateTime.now().toUtc(), 24.9, 46.9);
      await tracker.drain();
      expect(tracker.pendingCount.value, 2, reason: 'no new point after End');

      // Network back: the dead-zone fixes land after End, inside the window.
      connectivity.markOnline();
      await tracker.flushNow();
      expect(tracker.pendingCount.value, 0);
      track = await visits.readTrack(id);
      print('  final trail: ${[for (final l in track.logs) '${l.source.name}@${l.loggedAt.toIso8601String()}'].join(', ')}');
      final sources = track.logs.map((l) => l.source).toList();
      expect(sources.first, TrailSource.start);
      expect(sources.last, TrailSource.end);
      expect(sources.where((s) => s == TrailSource.track).length, 5);
      for (var i = 1; i < track.logs.length; i++) {
        expect(track.logs[i].loggedAt.isBefore(track.logs[i - 1].loggedAt), isFalse,
            reason: 'oldest first');
      }
      expect(track.logs.any((l) => l.latitude >= 24.8), isFalse,
          reason: 'nothing recorded after End reached the server');

      // The server refuses a point dated after the end, too (whole seconds:
      // the end's own second still counts as inside the window).
      await pause(2500);
      final late = await visits.logLocations(id, [
        TrailPoint(latitude: 24.71, longitude: 46.61, loggedAt: clock.now()),
      ]);
      print('  after end: created=${late.created} rejected=${late.rejected.map((r) => r.error)}');
      expect(late.created, 0);
      expect(late.rejected.single.index, 0);
      tracker.dispose();
    });

    test('visit A and visit B keep their own trails; nothing between them',
        () async {
      final a = await approvedVisit('isolation A');
      final b = await approvedVisit('isolation B');
      if (a == null || b == null) return markTestSkipped('account cannot approve');
      await VisitTrackingConsent(prefs).accept();
      final capture = _ScriptedCapture();
      final tracker = trackerFor(capture, ConnectivityStatus());

      Future<void> run(int id, double base) async {
        final started = await visits.start(id, latitude: base, longitude: base);
        await tracker.start(id, startedAt: started.at);
        await pause(3500);
        for (var i = 1; i <= 2; i++) {
          capture.move(id, DateTime.now().toUtc(), base + i * 0.001, base + i * 0.001);
          await pause(300);
        }
        await tracker.stop();
        await pause(1200);
        await visits.end(id, outcome: '$_qaTag done', latitude: base + 0.01, longitude: base + 0.01);
      }

      await run(a, 24.0);
      // Between the visits the phone keeps moving.
      capture.move(a, DateTime.now().toUtc(), 30.0, 30.0);
      capture.move(b, DateTime.now().toUtc(), 30.0, 30.0);
      await tracker.drain();
      await tracker.flushNow();
      await run(b, 26.0);

      final ta = await visits.readTrack(a);
      final tb = await visits.readTrack(b);
      print('  A: ${ta.logs.length} points, B: ${tb.logs.length} points');
      expect(ta.logs.length, 4, reason: 'start + 2 + end');
      expect(tb.logs.length, 4, reason: 'start + 2 + end');
      expect(ta.logs.every((l) => l.latitude < 25), isTrue);
      expect(tb.logs.every((l) => l.latitude > 25 && l.latitude < 27), isTrue);
      tracker.dispose();
    });

    test('a batch is filed by fix time and refused point by point', () async {
      final id = await approvedVisit('batch rules');
      if (id == null) return markTestSkipped('account cannot approve');
      final started = await visits.start(id, latitude: 24.7, longitude: 46.6);
      await pause(3000);
      final now = clock.now();
      final raw = await api.jsonRpc(Endpoints.visitLogLocations, params: {
        'visit_id': id,
        'points': [
          {'latitude': 24.72, 'longitude': 46.62, 'logged_at': VisitsRepository.formatOdooUtc(now)},
          {'latitude': 24.71, 'longitude': 46.61, 'logged_at': VisitsRepository.formatOdooUtc(now.subtract(const Duration(seconds: 1)))},
          {'latitude': 999.0, 'longitude': 46.6, 'logged_at': VisitsRepository.formatOdooUtc(now)},
          {'latitude': 24.73, 'longitude': 46.63, 'logged_at': 'garbage'},
          {'latitude': 24.74, 'longitude': 46.64, 'logged_at': VisitsRepository.formatOdooUtc(now.add(const Duration(minutes: 30)))},
          {'latitude': 24.75, 'longitude': 46.65, 'logged_at': VisitsRepository.formatOdooUtc(started.at!.subtract(const Duration(minutes: 10)))},
          {'latitude': 24.76, 'longitude': -181.0, 'logged_at': VisitsRepository.formatOdooUtc(now)},
        ],
      });
      final result = TrailFlushResult.fromApi(Map<String, dynamic>.from(raw as Map));
      print('  batch: created=${result.created} rejected=${[for (final r in result.rejected) '#${r.index} ${r.error}']}');
      expect(result.created, 2);
      expect(result.rejected.map((r) => r.index).toList()..sort(), [2, 3, 4, 5, 6]);

      final track = await visits.readTrack(id);
      final tracked = track.logs.where((l) => l.source == TrailSource.track).toList();
      expect(tracked.map((l) => l.latitude), [24.71, 24.72],
          reason: 'sent out of order, filed by logged_at');
      await visits.end(id, outcome: '$_qaTag done', latitude: 24.7, longitude: 46.6);
    });

    test('invalid transitions are refused with an explained message', () async {
      final id = await approvedVisit('transitions');
      if (id == null) return markTestSkipped('account cannot approve');
      Future<void> refused(String what, Future<Object?> Function() call) async {
        final e = await _expectApiError(call);
        print('  $what → ${e.code.name}: ${_userFacing(e)}');
        expect(e.messageFor(_en), isNot(_en.errUnknown));
        expect(e.code, isNot(ApiErrorCode.unauthorized));
      }

      await refused('approve twice', () => visits.approve(id));
      await refused('end an approved visit', () => visits.end(id, outcome: 'x', latitude: 24.7, longitude: 46.6));
      await visits.start(id, latitude: 24.7, longitude: 46.6);
      await refused('start twice', () => visits.start(id, latitude: 24.7, longitude: 46.6));
      await refused('submit a running visit', () => visits.submit(id));
      await visits.end(id, outcome: '$_qaTag done', latitude: 24.7, longitude: 46.6);
      await refused('reschedule a done visit', () => visits.reschedule(id, purpose: '$_qaTag late'));
      await refused('cancel a done visit', () => visits.cancel(id));
      final after = await visits.getVisit(id);
      expect(after?.state, VisitState.done);
    });

    test('reschedule: approved → reschedule_requested → approved', () async {
      final id = await approvedVisit('reschedule');
      if (id == null) return markTestSkipped('account cannot approve');
      final when = DateTime.now().toUtc().add(const Duration(days: 2));
      final state = await visits.reschedule(id,
          scheduledDatetime: when,
          purpose: '$_qaTag reschedule (moved)',
          location: '$_qaTag annex');
      expect(state, 'reschedule_requested');
      final moved = await visits.getVisit(id);
      expect(moved?.purpose, contains('(moved)'));
      expect(moved?.location, contains('annex'));
      expect(moved?.scheduledDatetime?.difference(when).inSeconds.abs() ?? 99, lessThan(2));
      final e = await _expectApiError(() => visits.start(id, latitude: 24.7, longitude: 46.6));
      print('  start while reschedule pending → ${_userFacing(e)}');
      expect(await visits.approve(id), 'approved');
      await visits.cancel(id);
    });

    test('a rejected visit can be submitted again', () async {
      final v = await visits.createVisit({
        'visit_type': 'project',
        'project_id': projectId,
        'scheduled_datetime': VisitsRepository.formatOdooUtc(
            DateTime.now().add(const Duration(hours: 4))),
        'purpose': '$_qaTag resubmit',
      });
      await visits.submit(v.id);
      expect(await visits.reject(v.id, '$_qaTag rejecting on purpose'), 'rejected');
      final rejected = await visits.getVisit(v.id);
      expect(rejected?.canSubmit, isTrue, reason: 'API.md: submit is allowed from rejected');
      expect(await visits.submit(v.id), 'submitted');
      await visits.cancel(v.id);
    });

    test('attendees gate the approval; own participation cannot be approved',
        () async {
      final v = await visits.createVisit({
        'visit_type': 'project',
        'project_id': projectId,
        'scheduled_datetime': VisitsRepository.formatOdooUtc(
            DateTime.now().add(const Duration(hours: 5))),
        'purpose': '$_qaTag attendee gate',
        if (user.employeeId != null) 'employee_id': user.employeeId,
      });
      final others = (await EmployeesRepository(api: api).list())
          .where((e) => e.hrEmployeeId != null && e.hrEmployeeId != user.employeeId)
          .map((e) => e.hrEmployeeId!)
          .take(1)
          .toList();
      if (others.isEmpty) {
        await visits.cancel(v.id);
        return markTestSkipped('no other employee to invite');
      }
      final ids = [...others, if (user.employeeId != null) user.employeeId!];
      try {
        await visits.addParticipants(v.id, ids);
      } on ApiException catch (e) {
        print('  adding self refused → ${_userFacing(e)}');
        await visits.addParticipants(v.id, others);
      }
      await visits.submit(v.id);
      final gate = await _expectApiError(() => visits.approve(v.id));
      print('  approve with pending attendees → ${_userFacing(gate)}');
      expect(gate.messageFor(_en), _en.errAttendeesPending);

      final lines = await visits.readParticipants(v.id);
      print('  participants: ${[for (final l in lines) '${l.employeeId}:${l.approvalState.name}']}');
      for (final line in lines) {
        try {
          await visits.approveParticipant(line.id);
          print('  participant ${line.employeeId} approved by this account');
          if (line.employeeId == user.employeeId) {
            // API.md §4.4: "nobody can approve their own participation". The
            // server lets a visit *administrator* do it — reported as a backend
            // deviation; enforced for every other role.
            print('  BACKEND DEVIATION: own participation approved '
                '(role ${user.visitRole.name})');
            if (user.visitRole != VisitRole.admin) {
              fail('a non-admin approved their own participation');
            }
          }
        } on ApiException catch (e) {
          print('  participant ${line.employeeId} approve refused → ${_userFacing(e)}');
        }
      }
      try {
        await visits.approveParticipant(lines.first.id);
      } on ApiException catch (e) {
        print('  repeated attendee decision → ${_userFacing(e)}');
      }
      await visits.cancel(v.id);
    });
  }, skip: _skip);

  group('attendee rejection', () {
    test('rejecting an attendee sends the visit back per the server policy',
        () async {
      final v = await visits.createVisit({
        'visit_type': 'project',
        'project_id': projectId,
        'scheduled_datetime': VisitsRepository.formatOdooUtc(
            DateTime.now().add(const Duration(hours: 6))),
        'purpose': '$_qaTag attendee reject',
        if (user.employeeId != null) 'employee_id': user.employeeId,
      });
      final other = (await EmployeesRepository(api: api).list())
          .where((e) => e.hrEmployeeId != null && e.hrEmployeeId != user.employeeId)
          .map((e) => e.hrEmployeeId!)
          .first;
      await visits.addParticipants(v.id, [other]);
      expect(await visits.submit(v.id), 'submitted');
      final line = (await visits.readParticipants(v.id)).single;
      await visits.rejectParticipant(line.id, '$_qaTag attendee on leave');
      final after = await visits.getVisit(v.id);
      final decided = (await visits.readParticipants(v.id)).single;
      print('  attendee rejected → participant=${decided.approvalState.name} '
          'visit=${after?.state.name} attendee track=${after?.attendeeApprovalState.name}');
      expect(decided.approvalState, ParticipantApprovalState.rejected);
      expect(after?.state, anyOf(VisitState.draft, VisitState.rejected),
          reason: 'API.md §4.4: draft (default policy) or rejected');
      final again = await _expectApiError(
          () => visits.rejectParticipant(line.id, '$_qaTag twice'));
      print('  rejecting twice → ${_userFacing(again)}');
      await visits.cancel(v.id);
    });
  }, skip: _skip);

  group('push device registration', () {
    test('register and unregister a token', () async {
      final push = PushRepository(api: api);
      final token = 'qa-auto-${DateTime.now().millisecondsSinceEpoch}';
      await push.registerDevice(token: token, platform: 'android', deviceId: 'qa-auto-device');
      await push.registerDevice(token: '$token-rotated', platform: 'android', deviceId: 'qa-auto-device');
      await push.registerDevice(token: '$token-ios', platform: 'ios', deviceId: 'qa-auto-ios');
      await push.unregisterDevice(token: '$token-rotated');
      await push.unregisterDevice(token: '$token-ios');
      final e = await _expectApiError(() => push.registerDevice(token: token, platform: 'windows'));
      print('  bad platform → ${e.code.name}: ${_userFacing(e)}');
    });
  }, skip: _skip);

  group('session and transport failures', () {
    test('an expired session is renewed transparently', () async {
      // Kill the session server-side without telling the client's auth layer.
      await api.dio.post(Endpoints.destroySession, data: {
        'jsonrpc': '2.0',
        'method': 'call',
        'params': <String, dynamic>{},
      });
      final mine = await visits.myVisits(limit: 1);
      print('  after server-side logout, my visits still load: ${mine.length}');
    });

    test('a route the server lacks reads as "not available"', () async {
      final e = await _expectApiError(() => api.jsonRpc('/api/visit/does_not_exist'));
      expect(e.code, ApiErrorCode.notSupported);
      print('  missing route → ${_userFacing(e)}');
    });

    test('a host that is not Odoo is explained', () async {
      final other = ApiClient(cookieJar: _tempJar(), baseUrl: 'https://example.com');
      final e = await _expectApiError(
          () => other.jsonRpc(Endpoints.authenticate, params: {'db': 'x'}));
      print('  non-Odoo host → ${e.code.name}: ${_userFacing(e)}');
      expect(e.code, isNot(ApiErrorCode.unknown));
    });

    test('an unresolvable host is a network error', () async {
      final other = ApiClient(
          cookieJar: _tempJar(), baseUrl: 'https://no-such-host.invalid');
      final e = await _expectApiError(() => other.jsonRpc(Endpoints.versionInfo));
      expect(e.code, ApiErrorCode.network);
      print('  unresolvable host → ${_userFacing(e)}');
    });

    test('logout invalidates the session', () async {
      await auth.logout();
      expect(await auth.currentUser(), isNull);
      final e = await _expectApiError(() => api.jsonRpc(Endpoints.visitMy));
      print('  after logout → ${e.code.name}: ${_userFacing(e)}');
      expect(e.code, ApiErrorCode.unauthorized);
    });
  }, skip: _skip);
}

/// The native visit capture, scripted: [move] is the phone moving — recorded
/// only while a visit is being captured, as the real service does — and
/// [inject] forces a fix into the journal regardless, to test the Dart-side
/// guard against a fix arriving after End.
class _ScriptedCapture extends VisitLocationChannel {
  final List<int> starts = [];
  bool active = false;
  int? visitId;
  DateTime? since;
  final List<CapturedFix> journal = [];
  int _seq = 0;

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
    starts.add(visitId);
    active = true;
    this.visitId = visitId;
    this.since = since;
  }

  @override
  Future<void> stop() async {
    active = false;
    visitId = null;
  }

  @override
  Future<CaptureStatus> status() async =>
      (active: active, running: active, visitId: visitId);

  @override
  Future<List<CapturedFix>> read({int max = journalReadBatch}) async =>
      journal.take(max).toList();

  @override
  Future<void> ack(int throughSeq) async =>
      journal.removeWhere((f) => f.seq <= throughSeq);

  void move(int visit, DateTime at, double lat, double lng) {
    final from = since;
    if (!active || visitId != visit || (from != null && at.isBefore(from))) return;
    inject(visit, at, lat, lng);
  }

  void inject(int visit, DateTime at, double lat, double lng) => journal.add(
        CapturedFix(
          seq: ++_seq,
          deviceTime: at,
          latitude: lat,
          longitude: lng,
          visitId: visit,
          accuracy: 5,
          speed: 3,
          heading: 45,
          altitude: 600,
        ),
      );
}

class _Permitted implements LocationService {
  @override
  Future<bool> hasPermission() async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
