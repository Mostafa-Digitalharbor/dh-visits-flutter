import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/utils/app_log.dart';
import '../../visits/data/models/visit.dart';
import '../../visits/data/models/visit_location_log.dart';
import '../../visits/data/visits_repository.dart';
import '../../visits/domain/visit_metrics.dart' show isSameDay;

/// One visit's server trail, kept together with the visit it belongs to.
///
/// The pairing is the point: the backend only exposes trails **per visit**
/// (`/api/visit/track`); there is no "employee's day" route. A day map is
/// composed client-side from several of these, and each stays its own line —
/// never concatenated into one path, which would draw the drive *between* two
/// visits as if it had been recorded during one of them.
class DayTrail extends Equatable {
  final Visit visit;
  final VisitTrack track;
  const DayTrail({required this.visit, required this.track});

  @override
  List<Object?> get props => [visit.id, track];
}

class DayTrailsState extends Equatable {
  final bool loading;
  final List<DayTrail> trails;

  /// How many of the day's visits could not be read. The rest still render —
  /// one refused trail must not blank the whole day.
  final int failed;

  const DayTrailsState({
    this.loading = false,
    this.trails = const [],
    this.failed = 0,
  });

  @override
  List<Object?> get props => [loading, trails, failed];
}

/// Loads the GPS trail of every visit the employee started on one day.
class DayTrailsCubit extends Cubit<DayTrailsState> {
  /// Null where no repository is registered (a widget test of the route tab):
  /// the day then simply shows no recorded routes.
  final VisitsRepository? repository;
  DayTrailsCubit({this.repository}) : super(const DayTrailsState());

  /// Visit ids of the last request, so a list rebuild with the same visits
  /// does not refetch every trail.
  String? _lastKey;

  /// Visits that were actually started on the local calendar day of [day],
  /// ordered by start time — the order the employee did them in.
  static List<Visit> startedOn(Iterable<Visit> visits, DateTime day) {
    final started = [
      for (final v in visits)
        if (v.startDatetime case final start?
            when isSameDay(start.toLocal(), day))
          (visit: v, start: start),
    ]..sort((a, b) => a.start.compareTo(b.start));
    return [for (final e in started) e.visit];
  }

  Future<void> load(List<Visit> visits, {bool force = false}) async {
    final key = visits.map((v) => '${v.id}:${v.state.name}').join(',');
    if (!force && key == _lastKey) return;
    _lastKey = key;
    final repo = repository;
    if (visits.isEmpty || repo == null) {
      if (!isClosed) emit(const DayTrailsState());
      return;
    }
    if (!isClosed) {
      // Keeps the previous figures on screen while the reload runs, the
      // failure count included — dropping it made the error line flicker.
      emit(DayTrailsState(
        loading: true,
        trails: state.trails,
        failed: state.failed,
      ));
    }

    final results = await Future.wait(visits.map((v) async {
      try {
        final track = await repo.readTrack(v.id);
        // Defensive isolation: a trail is only ever drawn under the visit that
        // asked for it.
        if (track.visitId != 0 && track.visitId != v.id) {
          appLog('[DayTrailsCubit] track for ${track.visitId} returned for '
              'visit ${v.id}; ignored');
          return null;
        }
        return DayTrail(visit: v, track: track);
      } on ApiException catch (e) {
        appLog('[DayTrailsCubit] trail of visit ${v.id} unavailable: ${e.code}');
        return null;
      } catch (e) {
        appLog('[DayTrailsCubit] trail of visit ${v.id} failed: $e');
        return null;
      }
    }));

    if (isClosed || key != _lastKey) return;
    emit(DayTrailsState(
      trails: [
        for (final r in results)
          if (r != null && r.track.logs.isNotEmpty) r,
      ],
      failed: results.where((r) => r == null).length,
    ));
  }
}
