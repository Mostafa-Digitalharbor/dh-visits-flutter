// Regression cover for two defects where the app told the user something it
// had not observed:
//
//   * Settings showed a fixed "Last sync: Just now", so a field employee with
//     unsent GPS-stamped check-ins was told their work was already uploaded.
//   * The visit role was matched against `res.groups` ids hardcoded from one
//     database. Odoo numbers those rows at install time and every company runs
//     its own Odoo, so on any other server the ids match nothing (role silently
//     drops to none, every approval button disappears) or match the wrong group.
//
// Fakes are hand-rolled via noSuchMethod, matching the other suites — no
// mocking package.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/core/api/api_exceptions.dart';
import 'package:location_gps/core/network/connectivity_status.dart';
import 'package:location_gps/core/network/pending_actions_queue.dart';
import 'package:location_gps/features/auth/data/models/user.dart';
import 'package:location_gps/features/visits/data/visits_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRepo implements VisitsRepository {
  _FakeRepo({this.startError});

  /// Thrown by [start] when set, to simulate a replay that can't go through.
  final Object? startError;
  int startCalls = 0;

  @override
  Future<String?> start(
    int visitId, {
    double? latitude,
    double? longitude,
    String? location,
    bool isMocked = false,
  }) async {
    startCalls++;
    if (startError != null) throw startError!;
    return 'in_progress';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

Future<PendingActionsQueue> _queue(_FakeRepo repo) async {
  final prefs = await SharedPreferences.getInstance();
  return PendingActionsQueue(
    prefs: prefs,
    repository: repo,
    connectivity: ConnectivityStatus(),
  );
}

void main() {
  group('VisitGroupMemberships.role', () {
    test('maps each membership to its role', () {
      expect(const VisitGroupMemberships(user: true).role, VisitRole.user);
      expect(const VisitGroupMemberships(manager: true).role, VisitRole.manager);
      expect(const VisitGroupMemberships(projectManager: true).role,
          VisitRole.projectManager);
      expect(const VisitGroupMemberships(admin: true).role, VisitRole.admin);
    });

    test('highest role wins when the user is in several groups', () {
      expect(
        const VisitGroupMemberships(user: true, manager: true, admin: true).role,
        VisitRole.admin,
      );
      expect(
        const VisitGroupMemberships(user: true, manager: true).role,
        VisitRole.manager,
      );
    });

    test('no membership means no role', () {
      expect(VisitGroupMemberships.none.role, VisitRole.none);
      expect(VisitGroupMemberships.none.isEmpty, isTrue);
    });

    test('a manager keeps the manager role', () {
      // The regression this guards: resolving groups through `ir.model.data`
      // raised AccessError for every non-admin user, so the profile read failed
      // and the role silently fell back to `none` — demoting every manager to a
      // field rep with no approval buttons. Membership is now answered by
      // `res.users.has_group`, which any user may ask about themselves.
      const mona = VisitGroupMemberships(user: true, manager: true);
      expect(mona.role, VisitRole.manager);
      expect(mona.isEmpty, isFalse);
    });
  });

  group('PendingActionsQueue.lastSyncedAt', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('is null before anything has ever synced', () async {
      final q = await _queue(_FakeRepo());
      expect(q.lastSyncedAt.value, isNull);
    });

    test('a flush with an empty queue does not claim a sync', () async {
      final q = await _queue(_FakeRepo());
      await q.flush();
      expect(q.lastSyncedAt.value, isNull,
          reason: 'nothing was sent, so there is no sync to report');
    });

    test('stamps the time when a queued action really reaches the server',
        () async {
      final repo = _FakeRepo();
      final q = await _queue(repo);
      await q.enqueue(1, {'type': 'start', 'latitude': 1.0, 'longitude': 2.0});
      expect(q.pendingCount.value, 1);

      await q.flush();

      expect(repo.startCalls, 1);
      expect(q.pendingCount.value, 0);
      expect(q.lastSyncedAt.value, isNotNull);
    });

    test('a flush that stays offline leaves the timestamp untouched', () async {
      // The defect this guards: reporting "synced just now" while the user's
      // check-in is still sitting in the queue.
      final repo = _FakeRepo(
        startError: ApiException(code: ApiErrorCode.network),
      );
      final q = await _queue(repo);
      await q.enqueue(1, {'type': 'start'});

      await q.flush();

      expect(q.pendingCount.value, 1, reason: 'still queued');
      expect(q.lastSyncedAt.value, isNull, reason: 'nothing reached the server');
    });

    test('a dropped (server-refused) action is not counted as a sync',
        () async {
      final repo = _FakeRepo(
        startError: ApiException(code: ApiErrorCode.permissionDenied),
      );
      final q = await _queue(repo);
      await q.enqueue(1, {'type': 'start'});

      final dropped = <DroppedAction>[];
      q.onDropped.listen(dropped.add);
      await q.flush();
      await Future<void>.delayed(Duration.zero);

      expect(q.pendingCount.value, 0, reason: 'abandoned, not retried forever');
      expect(dropped, hasLength(1));
      expect(q.lastSyncedAt.value, isNull,
          reason: 'the work was lost, not synced');
    });

    test('survives a restart via SharedPreferences', () async {
      final repo = _FakeRepo();
      final first = await _queue(repo);
      await first.enqueue(1, {'type': 'start'});
      await first.flush();
      final stamped = first.lastSyncedAt.value;
      expect(stamped, isNotNull);

      // Cold start against the same prefs.
      final second = await _queue(_FakeRepo());
      expect(second.lastSyncedAt.value, stamped);
    });

    test('an unreplayable action is announced, not reported as synced',
        () async {
      // The defect: `_replay`'s default arm returned normally for an unknown
      // action type, so flush counted it a success — fired `_synced`, stamped
      // "Last sync = now" and deleted the entry. The user was told work had
      // uploaded that had in fact been thrown away.
      final q = await _queue(_FakeRepo());
      await q.enqueue(1, {'type': 'teleport'});

      final dropped = <DroppedAction>[];
      q.onDropped.listen(dropped.add);
      await q.flush();
      await Future<void>.delayed(Duration.zero);

      expect(dropped, hasLength(1), reason: 'the loss must be announced');
      expect(dropped.single.visitId, 1);
      expect(q.lastSyncedAt.value, isNull,
          reason: 'nothing reached the server, so nothing synced');
      expect(q.pendingCount.value, 0, reason: 'not retried forever');
    });
  });

  group('PendingActionsQueue durability', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('one corrupt entry does not discard the whole queue', () async {
      // The defect: the per-entry parse sat inside the same try as jsonDecode,
      // so a single malformed record threw and `_readAll` returned [] — wiping
      // every other queued check-in, with pendingCount reading 0 so neither the
      // offline banner nor Settings showed anything had been lost.
      SharedPreferences.setMockInitialValues({
        'pending_visit_actions_v1': jsonEncode([
          {
            'visitId': 1,
            'payload': {'type': 'start'},
            'queuedAt': DateTime.now().toIso8601String(),
          },
          // Malformed: null visitId, as a partial write would leave it.
          {
            'visitId': null,
            'payload': {'type': 'start'},
            'queuedAt': DateTime.now().toIso8601String(),
          },
          {
            'visitId': 3,
            'payload': {'type': 'start'},
            'queuedAt': DateTime.now().toIso8601String(),
          },
        ]),
      });

      final q = await _queue(_FakeRepo());

      expect(q.pendingCount.value, 2,
          reason: 'the two readable check-ins must survive');
      expect(q.pending.map((a) => a.visitId), [1, 3]);
    });

    test('a wholly unreadable blob still degrades to empty', () async {
      SharedPreferences.setMockInitialValues({
        'pending_visit_actions_v1': 'not json at all',
      });
      final q = await _queue(_FakeRepo());
      expect(q.pendingCount.value, 0);
    });

    test('start and end for one visit both queue, in order', () async {
      // The defect: enqueue keyed on visitId alone, so an offline End replaced
      // the offline Start. The server then got an End for a visit it still had
      // as `approved`, refused it, and the rep's whole dead-zone visit was lost.
      final q = await _queue(_FakeRepo());
      await q.enqueue(1, {'type': 'start'});
      await q.enqueue(1, {'type': 'end', 'outcome': 'ok'});

      expect(q.pendingCount.value, 2);
      expect(q.pending.map((a) => a.payload['type']), ['start', 'end']);
    });

    test('a repeated tap of the same action still replaces', () async {
      // Same-type dedupe is why the visit-only key existed; keep it working.
      final q = await _queue(_FakeRepo());
      await q.enqueue(1, {'type': 'start', 'latitude': 1.0});
      await q.enqueue(1, {'type': 'start', 'latitude': 2.0});

      expect(q.pendingCount.value, 1);
      expect(q.pending.single.payload['latitude'], 2.0,
          reason: 'the latest intent wins');
    });

    test('actions for different visits are independent', () async {
      final q = await _queue(_FakeRepo());
      await q.enqueue(1, {'type': 'start'});
      await q.enqueue(2, {'type': 'start'});
      expect(q.pendingCount.value, 2);
    });
  });
}
