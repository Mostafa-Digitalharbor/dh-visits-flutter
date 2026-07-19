// Covers the two invisible-but-real defects in VisitDetailCubit:
//   * attachments were fetched from the view on every rebuild
//   * emit-after-close threw a StateError when the user popped mid-request
//
// The fake implements VisitsRepository via noSuchMethod, so only the methods a
// test actually exercises need defining and no mocking package is required.
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/core/api/api_exceptions.dart';
import 'package:location_gps/features/visits/bloc/visit_detail_cubit.dart';
import 'package:location_gps/features/visits/data/models/visit.dart';
import 'package:location_gps/features/visits/data/models/visit_attachment.dart';
import 'package:location_gps/features/visits/data/visits_repository.dart';

class _FakeRepo implements VisitsRepository {
  _FakeRepo({
    this.visit,
    this.attachments = const [],
    this.attachmentsError,
    this.readDelay = Duration.zero,
    this.mockFlagged = false,
  });

  final Visit? visit;
  final List<VisitAttachment> attachments;
  final Object? attachmentsError;
  final Duration readDelay;
  bool mockFlagged;

  int readVisitFullCalls = 0;
  int readAttachmentsCalls = 0;
  int mockFlagCalls = 0;

  /// Recorded so a test can assert what actually reached the wire — the whole
  /// class of bug here is a value being computed and then dropped en route.
  final List<Map<String, Object?>> startCalls = [];
  final List<Map<String, Object?>> endCalls = [];

  @override
  Future<Visit?> readVisitFull(int visitId) async {
    readVisitFullCalls++;
    if (readDelay > Duration.zero) await Future<void>.delayed(readDelay);
    return visit;
  }

  @override
  Future<List<VisitAttachment>> readAttachments(int visitId) async {
    readAttachmentsCalls++;
    if (attachmentsError != null) throw attachmentsError!;
    return attachments;
  }

  @override
  Future<bool> hasMockLocationFlag(int visitId) async {
    mockFlagCalls++;
    return mockFlagged;
  }

  @override
  Future<String?> start(
    int visitId, {
    double? latitude,
    double? longitude,
    String? location,
    bool isMocked = false,
  }) async {
    startCalls.add({
      'latitude': latitude,
      'longitude': longitude,
      'location': location,
      'isMocked': isMocked,
    });
    // The server records the verdict, so a later read sees it.
    if (isMocked) mockFlagged = true;
    return 'in_progress';
  }

  @override
  Future<String?> end(
    int visitId, {
    required String outcome,
    double? latitude,
    double? longitude,
    String? location,
    bool isMocked = false,
  }) async {
    endCalls.add({
      'outcome': outcome,
      'latitude': latitude,
      'longitude': longitude,
      'location': location,
      'isMocked': isMocked,
    });
    if (isMocked) mockFlagged = true;
    return 'done';
  }

  @override
  Future<String?> approve(int visitId) async => null;

  // Anything a test doesn't stub is a bug in the test, not a silent null.
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      'Unstubbed: ${invocation.memberName}');
}

void main() {
  const visit = Visit(id: 7, name: 'V-0007', attachmentCount: 2);
  const attachments = [
    VisitAttachment(id: 1, name: 'report.pdf', mimetype: 'application/pdf'),
    VisitAttachment(id: 2, name: 'site.jpg', mimetype: 'image/jpeg'),
  ];

  group('load', () {
    test('reads attachments exactly once, into state', () async {
      // The regression: the view built its FutureBuilder future inside build(),
      // so opening the page fired repeated search_read calls and every later
      // rebuild fired more. Loading once into state is the whole fix.
      final repo = _FakeRepo(visit: visit, attachments: attachments);
      final cubit = VisitDetailCubit(repository: repo, visitId: 7);

      await cubit.load();

      expect(repo.readAttachmentsCalls, 1);
      expect(cubit.state.attachments, attachments);
      expect(cubit.state.status, VisitDetailStatus.ready);
      expect(cubit.state.attachmentsError, isNull);
      await cubit.close();
    });

    test('an attachments failure does not blank the visit', () async {
      // Attachments are secondary: a failed read must render in-place, not
      // take the whole screen to an error state.
      final repo = _FakeRepo(
        visit: visit,
        attachmentsError: ApiException(code: ApiErrorCode.permissionDenied),
      );
      final cubit = VisitDetailCubit(repository: repo, visitId: 7);

      await cubit.load();

      expect(cubit.state.status, VisitDetailStatus.ready);
      expect(cubit.state.visit, visit);
      expect(cubit.state.attachmentsError, isNotNull);
      expect(cubit.state.attachments, isEmpty);
      await cubit.close();
    });
  });

  group('mock-location verdict', () {
    // The regression this guards: isMocked was computed in the action bar,
    // shown to the user, and then dropped at the callback boundary, so the
    // app's own "this will be flagged for review" message was untrue.
    test('start() forwards isMocked and the geocoded label to the repo',
        () async {
      final repo = _FakeRepo(visit: visit);
      final cubit = VisitDetailCubit(repository: repo, visitId: 7);

      await cubit.start(
        latitude: 24.71355,
        longitude: 46.67529,
        location: 'شارع العليا، الرياض',
        isMocked: true,
      );

      expect(repo.startCalls, hasLength(1));
      expect(repo.startCalls.single['isMocked'], isTrue);
      expect(repo.startCalls.single['location'], 'شارع العليا، الرياض');
      expect(repo.startCalls.single['latitude'], 24.71355);
      await cubit.close();
    });

    test('end() forwards isMocked and the geocoded label to the repo',
        () async {
      final repo = _FakeRepo(visit: visit);
      final cubit = VisitDetailCubit(repository: repo, visitId: 7);

      await cubit.end(
        outcome: 'done',
        latitude: 24.7,
        longitude: 46.6,
        location: 'Olaya St',
        isMocked: true,
      );

      expect(repo.endCalls.single['isMocked'], isTrue);
      expect(repo.endCalls.single['location'], 'Olaya St');
      await cubit.close();
    });

    test('a clean fix does not raise the flag', () async {
      final repo = _FakeRepo(visit: visit);
      final cubit = VisitDetailCubit(repository: repo, visitId: 7);

      await cubit.start(latitude: 24.7, longitude: 46.6, location: 'Olaya St');

      expect(repo.startCalls.single['isMocked'], isFalse);
      expect(cubit.state.mockFlagged, isFalse);
      await cubit.close();
    });

    test('starting with a mocked fix raises the banner immediately', () async {
      final repo = _FakeRepo(visit: visit);
      final cubit = VisitDetailCubit(repository: repo, visitId: 7);

      await cubit.start(latitude: 24.7, longitude: 46.6, isMocked: true);

      expect(cubit.state.mockFlagged, isTrue,
          reason: 'the verdict must be visible without a manual refresh');
      await cubit.close();
    });

    test('load() surfaces a flag recorded on an earlier action', () async {
      final repo = _FakeRepo(visit: visit, mockFlagged: true);
      final cubit = VisitDetailCubit(repository: repo, visitId: 7);

      await cubit.load();

      expect(cubit.state.mockFlagged, isTrue);
      expect(repo.mockFlagCalls, 1, reason: 'one cheap query, not per-rebuild');
      await cubit.close();
    });

    // The emits in _run build a fresh VisitDetailState instead of copyWith, so
    // each one has to carry the flag explicitly. Approving a flagged visit used
    // to be enough to clear the warning off the screen.
    test('a later action does not clear an already-raised flag', () async {
      final repo = _FakeRepo(visit: visit, mockFlagged: true);
      final cubit = VisitDetailCubit(repository: repo, visitId: 7);

      await cubit.load();
      expect(cubit.state.mockFlagged, isTrue);

      await cubit.approve();

      expect(cubit.state.mockFlagged, isTrue,
          reason: 'approving must not erase the spoofing warning');
      await cubit.close();
    });
  });

  group('emit after close', () {
    test('load() completing after close does not throw', () async {
      // Repro: open a visit on a slow link, press Back before it returns.
      // Cubit.emit throws StateError once closed (bloc 8.1.4), surfacing as an
      // unhandled async error.
      final repo = _FakeRepo(
        visit: visit,
        attachments: attachments,
        readDelay: const Duration(milliseconds: 50),
      );
      final cubit = VisitDetailCubit(repository: repo, visitId: 7);

      final pending = cubit.load();
      await cubit.close();

      await expectLater(pending, completes);
    });

    test('an action completing after close does not throw', () async {
      // Same race on the workflow path: tap Approve, then pop.
      final repo = _FakeRepo(
        visit: visit,
        attachments: attachments,
        readDelay: const Duration(milliseconds: 50),
      );
      final cubit = VisitDetailCubit(repository: repo, visitId: 7);

      final pending = cubit.approve();
      await cubit.close();

      await expectLater(pending, completes);
    });
  });
}
