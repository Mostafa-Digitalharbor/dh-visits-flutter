// The day map is composed client-side from per-visit trails (the backend has no
// whole-day route). What must hold: only visits actually started that day, in
// the order they were done, each trail kept under its own visit, and one
// refused trail never blanking the rest.
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/core/api/api_exceptions.dart';
import 'package:location_gps/features/route/bloc/day_trails_cubit.dart';
import 'package:location_gps/features/visits/data/models/visit.dart';
import 'package:location_gps/features/visits/data/models/visit_location_log.dart';
import 'package:location_gps/features/visits/data/visits_repository.dart';

class _Repo implements VisitsRepository {
  _Repo(this.tracks, {this.failFor = const {}});
  final Map<int, VisitTrack> tracks;
  final Set<int> failFor;
  final List<int> reads = [];

  @override
  Future<VisitTrack> readTrack(int visitId,
      {int? limit, int offset = 0, DateTime? dateFrom, DateTime? dateTo}) async {
    reads.add(visitId);
    if (failFor.contains(visitId)) {
      throw ApiException(code: ApiErrorCode.permissionDenied);
    }
    return tracks[visitId]!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

VisitTrack _track(int visitId, List<(double, double)> coords) => VisitTrack(
      visitId: visitId,
      locationLogCount: coords.length,
      logs: [
        for (var i = 0; i < coords.length; i++)
          VisitLocationLog(
            id: visitId * 100 + i,
            visitId: visitId,
            loggedAt: DateTime.utc(2026, 9, 13, 9, i),
            latitude: coords[i].$1,
            longitude: coords[i].$2,
          ),
      ],
    );

void main() {
  final day = DateTime(2026, 9, 13, 12);
  final a = Visit(id: 1, state: VisitState.done, startDatetime: DateTime(2026, 9, 13, 9).toUtc());
  final b = Visit(id: 2, state: VisitState.done, startDatetime: DateTime(2026, 9, 13, 11, 30).toUtc());
  final c = Visit(id: 3, state: VisitState.inProgress, startDatetime: DateTime(2026, 9, 13, 14).toUtc());
  final yesterday = Visit(id: 4, state: VisitState.done, startDatetime: DateTime(2026, 9, 12, 10).toUtc());
  const notStarted = Visit(id: 5, state: VisitState.approved);

  test('startedOn keeps only that day\'s started visits, in start order', () {
    final picked = DayTrailsCubit.startedOn([c, notStarted, b, yesterday, a], day);
    expect(picked.map((v) => v.id), [1, 2, 3]);
  });

  test('each visit keeps its own trail; points never move between visits',
      () async {
    final repo = _Repo({
      1: _track(1, [(24.71, 46.67), (24.72, 46.68)]),
      2: _track(2, [(24.69, 46.72), (24.70, 46.73), (24.71, 46.74)]),
    });
    final cubit = DayTrailsCubit(repository: repo);

    await cubit.load([a, b]);

    expect(cubit.state.trails.map((t) => t.visit.id), [1, 2]);
    for (final t in cubit.state.trails) {
      expect(t.track.logs.every((l) => l.visitId == t.visit.id), isTrue);
    }
    expect(cubit.state.trails[1].track.logs, hasLength(3));
    await cubit.close();
  });

  test('a trail returned for another visit is not drawn under this one',
      () async {
    final repo = _Repo({1: _track(99, [(24.71, 46.67), (24.72, 46.68)])});
    final cubit = DayTrailsCubit(repository: repo);

    await cubit.load([a]);

    expect(cubit.state.trails, isEmpty);
    expect(cubit.state.failed, 1);
    await cubit.close();
  });

  test('one refused trail does not hide the others', () async {
    final repo = _Repo({2: _track(2, [(24.69, 46.72), (24.70, 46.73)])},
        failFor: {1});
    final cubit = DayTrailsCubit(repository: repo);

    await cubit.load([a, b]);

    expect(cubit.state.trails.map((t) => t.visit.id), [2]);
    expect(cubit.state.failed, 1);
    await cubit.close();
  });

  test('the same visits do not refetch every trail', () async {
    final repo = _Repo({1: _track(1, [(24.71, 46.67), (24.72, 46.68)])});
    final cubit = DayTrailsCubit(repository: repo);

    await cubit.load([a]);
    await cubit.load([a]);

    expect(repo.reads, [1]);
    await cubit.close();
  });
}
