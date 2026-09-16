// The contract between the visit workflow and GPS tracking (docs/API.md §4.6,
// docs/VISIT_TRACKING.md):
//
// * recording starts only when the server confirms the visit is `in_progress`
//   — never on a refused, unexpected or offline-queued Start;
// * End stops recording *before* the request goes out, and a refused End on a
//   visit that is still running restarts it;
// * reading a visit can stop recording (it is over) but never start it;
// * on app start the server decides, and offline the local marker does.
//
// The tracker itself is covered in visit_trail_test.dart; here it is a fake
// that records what the workflow asked of it.
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/core/api/api_exceptions.dart';
import 'package:location_gps/core/network/connectivity_status.dart';
import 'package:location_gps/core/network/pending_actions_queue.dart';
import 'package:location_gps/features/visits/bloc/visit_bloc.dart'
    hide VisitState;
import 'package:location_gps/features/visits/bloc/visit_detail_cubit.dart';
import 'package:location_gps/features/visits/data/models/visit.dart';
import 'package:location_gps/features/visits/data/models/visit_attachment.dart';
import 'package:location_gps/features/visits/data/visit_trail_tracker.dart';
import 'package:location_gps/features/visits/data/visits_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _startedAt = DateTime.utc(2026, 9, 16, 10);

class _Repo implements VisitsRepository {
  _Repo(this.log);

  final List<String> log;

  /// The visit's state as the server reports it on a read.
  VisitState? state = VisitState.approved;

  /// What Start / End answer, or throw.
  VisitTransition startAnswer = (state: VisitState.inProgress, at: _startedAt);
  Object? startError;
  Object? endError;

  /// What `myRunningVisit` answers, or throws.
  Visit? running;
  Object? runningError;

  Visit? get _visit => state == null
      ? null
      : Visit(id: 7, state: state!, startDatetime: _startedAt);

  @override
  Future<Visit?> readVisitFull(int visitId) async => _visit;

  @override
  Future<Visit?> getVisit(int visitId) async => _visit;

  @override
  Future<List<VisitAttachment>> readAttachments(int visitId) async => const [];

  @override
  Future<bool> hasMockLocationFlag(int visitId) async => false;

  @override
  Future<VisitTransition> start(
    int visitId, {
    double? latitude,
    double? longitude,
    String? location,
    bool isMocked = false,
  }) async {
    log.add('repo.start');
    if (startError != null) throw startError!;
    if (startAnswer.state == VisitState.inProgress) {
      state = VisitState.inProgress;
    }
    return startAnswer;
  }

  @override
  Future<VisitTransition> end(
    int visitId, {
    required String outcome,
    double? latitude,
    double? longitude,
    String? location,
    bool isMocked = false,
  }) async {
    log.add('repo.end');
    if (endError != null) throw endError!;
    state = VisitState.done;
    return (state: VisitState.done, at: _startedAt.add(const Duration(hours: 1)));
  }

  @override
  Future<void> cancel(int visitId) async {
    log.add('repo.cancel');
    state = VisitState.cancelled;
  }

  @override
  Future<Visit?> myRunningVisit() async {
    if (runningError != null) throw runningError!;
    return running;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unstubbed: ${invocation.memberName}');
}

class _Tracker implements VisitTrailTracker {
  _Tracker(this.log);
  final List<String> log;
  int? active;

  @override
  int? get activeVisitId => active;

  @override
  Future<void> start(
    int visitId, {
    DateTime? startedAt,
    double? seedLatitude,
    double? seedLongitude,
  }) async {
    log.add('trail.start $visitId $startedAt $seedLatitude');
    active = visitId;
  }

  @override
  Future<void> stop({bool flush = true, DateTime? endedAt}) async {
    log.add('trail.stop');
    active = null;
  }

  @override
  Future<void> drain() async => log.add('trail.drain');

  @override
  Future<void> flushNow({bool probe = false}) async => log.add('trail.flush');

  @override
  Future<void> resume(Visit? running) async =>
      log.add('trail.resume ${running?.id}');

  @override
  Future<void> resumeUnverified() async => log.add('trail.resumeUnverified');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unstubbed: ${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<String> log;
  late _Repo repo;
  late _Tracker tracker;
  late PendingActionsQueue queue;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    log = [];
    repo = _Repo(log);
    tracker = _Tracker(log);
    queue = PendingActionsQueue(
      prefs: await SharedPreferences.getInstance(),
      repository: repo,
      connectivity: ConnectivityStatus()..markOffline(),
    );
  });

  tearDown(() => queue.dispose());

  VisitDetailCubit cubit() => VisitDetailCubit(
        repository: repo,
        visitId: 7,
        tracker: tracker,
        pendingActions: queue,
      );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('Start', () {
    test('records the trail once the server confirms in_progress', () async {
      final c = cubit();
      final ok = await c.start(latitude: 24.7, longitude: 46.6);
      await settle();

      expect(ok, isTrue);
      expect(log, ['repo.start', 'trail.start 7 $_startedAt 24.7']);
      await c.close();
    });

    test('records nothing when the server answers another state', () async {
      repo.startAnswer = (state: VisitState.approved, at: null);
      final c = cubit();
      await c.start(latitude: 24.7, longitude: 46.6);
      await settle();

      expect(log, ['repo.start']);
      await c.close();
    });

    test('records nothing when the server refuses the Start', () async {
      repo.startError = ApiException(
        code: ApiErrorCode.validation,
        serverMessage: 'Only an approved visit can be started.',
      );
      final c = cubit();
      final ok = await c.start(latitude: 24.7, longitude: 46.6);
      await settle();

      expect(ok, isFalse);
      expect(log, ['repo.start']);
      expect(c.state.error?.code, ApiErrorCode.validation);
      await c.close();
    });

    test('an offline Start is queued and records nothing yet', () async {
      repo.startError = ApiException(code: ApiErrorCode.network);
      final c = cubit();
      final ok = await c.start(latitude: 24.7, longitude: 46.6);
      await settle();

      expect(ok, isTrue);
      expect(c.state.lastAction?.queued, isTrue);
      expect(queue.pending.single.visitId, 7);
      expect(log.where((e) => e.startsWith('trail.start')), isEmpty);
      await c.close();
    });
  });

  group('End', () {
    setUp(() {
      repo.state = VisitState.inProgress;
      tracker.active = 7;
    });

    test('stops recording before the End goes out', () async {
      final c = cubit();
      final ok = await c.end(outcome: 'Signed', latitude: 24.7, longitude: 46.6);
      await settle();

      expect(ok, isTrue);
      expect(log, ['trail.stop', 'repo.end']);
      expect(tracker.active, isNull);
      await c.close();
    });

    test('a refused End on a running visit restarts recording', () async {
      repo.endError = ApiException(
        code: ApiErrorCode.validation,
        serverMessage: 'The visit outcome is required before ending the visit.',
      );
      final c = cubit();
      final ok = await c.end(outcome: '', latitude: 24.7, longitude: 46.6);
      await settle();

      expect(ok, isFalse);
      expect(log.first, 'trail.stop');
      expect(log.last, 'trail.start 7 $_startedAt null');
      await c.close();
    });

    test('an offline End is queued and recording stays stopped', () async {
      repo.endError = ApiException(code: ApiErrorCode.timeout);
      final c = cubit();
      await c.load();
      final ok = await c.end(outcome: 'Signed', latitude: 24.7, longitude: 46.6);
      await settle();

      expect(ok, isTrue);
      expect(log, ['trail.stop', 'repo.end']);
      expect(c.state.visit?.state, VisitState.done);
      await c.close();
    });

    test('ending a visit this device is not recording only flushes', () async {
      tracker.active = 9;
      final c = cubit();
      await c.end(outcome: 'Signed', latitude: 24.7, longitude: 46.6);
      await settle();

      expect(log, ['trail.drain', 'trail.flush', 'repo.end']);
      expect(tracker.active, 9, reason: 'the other visit keeps recording');
      await c.close();
    });
  });

  group('reads', () {
    test('a visit found cancelled stops its recording', () async {
      repo.state = VisitState.cancelled;
      tracker.active = 7;
      final c = cubit();
      await c.load();
      await settle();

      expect(log, ['trail.stop']);
      await c.close();
    });

    test('cancelling the running visit stops its recording', () async {
      repo.state = VisitState.inProgress;
      tracker.active = 7;
      final c = cubit();
      await c.cancel();
      await settle();

      expect(log, ['repo.cancel', 'trail.stop']);
      await c.close();
    });

    test('reading a running visit never starts recording', () async {
      repo.state = VisitState.inProgress;
      final c = cubit();
      await c.load();
      await settle();

      expect(log, isEmpty);
      await c.close();
    });
  });

  group('restore on app start', () {
    VisitBloc bloc() =>
        VisitBloc(repository: repo, tracker: tracker, pendingActions: queue);

    test('the server\'s running visit is resumed', () async {
      repo.running = Visit(id: 7, state: VisitState.inProgress, startDatetime: _startedAt);
      final b = bloc()..add(const VisitResumeRequested());
      await settle();
      await settle();

      expect(b.state.activeVisit?.id, 7);
      expect(log, ['trail.resume 7']);
      await b.close();
    });

    test('nothing running on the server stops any recording', () async {
      final b = bloc()..add(const VisitResumeRequested());
      await settle();
      await settle();

      expect(b.state.activeVisit, isNull);
      expect(log, ['trail.resume null']);
      await b.close();
    });

    test('offline, the local marker decides until the server can', () async {
      repo.runningError = ApiException(code: ApiErrorCode.network);
      final b = bloc()..add(const VisitResumeRequested());
      await settle();
      await settle();

      expect(log, ['trail.resumeUnverified']);
      await b.close();
    });
  });
}
