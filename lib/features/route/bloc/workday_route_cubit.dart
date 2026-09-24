import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/storage/session_storage.dart';
import '../../../core/utils/app_log.dart';
import '../../workday/data/models/workday_models.dart';
import '../../workday/data/workday_repository.dart';
import '../../workday/data/workday_tracker.dart';

class WorkdayRouteState extends Equatable {
  final bool loading;
  final List<WorkdayRoute> routes;

  /// The last read failed; [routes] still holds what was shown before.
  final bool failed;

  const WorkdayRouteState({
    this.loading = false,
    this.routes = const [],
    this.failed = false,
  });

  @override
  List<Object?> get props => [loading, routes, failed];
}

/// Today's work-day route(s) as the server stores them — the authoritative
/// daily route, including the movement between visits.
///
/// Reloads whenever the tracker lands new points, so an open route screen
/// follows the day as it is recorded.
class WorkdayRouteCubit extends Cubit<WorkdayRouteState> {
  /// Null where not registered (a widget test of the tab): no day route.
  final WorkdayRepository? repository;
  final SessionStorage? sessionStorage;
  final WorkdayTracker? tracker;

  WorkdayRouteCubit({this.repository, this.sessionStorage, this.tracker})
      : super(const WorkdayRouteState()) {
    tracker?.revision.addListener(_onRevision);
  }

  bool _reloadQueued = false;

  void _onRevision() {
    if (state.loading) {
      _reloadQueued = true;
      return;
    }
    load();
  }

  Future<void> load() async {
    final repo = repository;
    final user = await sessionStorage?.getUser();
    final uid = (user?['uid'] as num?)?.toInt();
    if (repo == null || uid == null) {
      if (!isClosed) emit(const WorkdayRouteState());
      return;
    }
    if (!isClosed) {
      emit(WorkdayRouteState(loading: true, routes: state.routes));
    }
    try {
      final sessions = await repo.sessionsForDay(uid, DateTime.now());
      final routes = await Future.wait(sessions.map(repo.readRoute));
      if (!isClosed) emit(WorkdayRouteState(routes: routes));
    } on ApiException catch (e) {
      if (WorkdayRepository.isMissingModel(e)) {
        if (!isClosed) emit(const WorkdayRouteState());
      } else {
        appLog('[WorkdayRouteCubit] day route unavailable: ${e.code}');
        if (!isClosed) emit(WorkdayRouteState(routes: state.routes, failed: true));
      }
    } catch (e) {
      appLog('[WorkdayRouteCubit] day route failed: $e');
      if (!isClosed) emit(WorkdayRouteState(routes: state.routes, failed: true));
    }
    if (_reloadQueued && !isClosed) {
      _reloadQueued = false;
      await load();
    }
  }

  @override
  Future<void> close() {
    tracker?.revision.removeListener(_onRevision);
    return super.close();
  }
}
