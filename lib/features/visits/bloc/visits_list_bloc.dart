import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/api/api_exceptions.dart';
import '../data/models/visit.dart';
import '../data/visits_repository.dart';

part 'visits_list_event.dart';
part 'visits_list_state.dart';

/// Drives the main visits list screen. Backend record rules already scope
/// the list to the logged-in user's permissions (Manager sees all, User
/// sees own), so we don't pass `employee_id` from the mobile.
///
/// The Today/All filter is applied **client-side** — the backend's
/// `date_from`/`date_to` query params don't work reliably yet for visits
/// without a check-in time (still pending as a backend ask).
class VisitsListBloc extends Bloc<VisitsListEvent, VisitsListState> {
  final VisitsRepository repository;

  VisitsListBloc({required this.repository}) : super(const VisitsListState()) {
    on<VisitsListLoadRequested>(_onLoad);
    on<VisitsListFilterChanged>(_onFilterChanged);
    on<VisitsListSearchChanged>(_onSearchChanged);
    on<VisitsListStatusFilterChanged>(_onStatusFilterChanged);
    on<VisitsListTimingFilterChanged>(_onTimingFilterChanged);
  }

  void _onSearchChanged(
    VisitsListSearchChanged event,
    Emitter<VisitsListState> emit,
  ) {
    emit(state.copyWith(searchQuery: event.query));
  }

  void _onStatusFilterChanged(
    VisitsListStatusFilterChanged event,
    Emitter<VisitsListState> emit,
  ) {
    emit(state.copyWith(statusFilter: event.filter));
  }

  void _onTimingFilterChanged(
    VisitsListTimingFilterChanged event,
    Emitter<VisitsListState> emit,
  ) {
    emit(state.copyWith(timingFilter: event.filter));
  }

  /// Minimum time the skeleton stays visible before swapping to data.
  /// Anything shorter feels like a flash; this lets the eye register the
  /// loading state.
  static const _minSkeleton = Duration(milliseconds: 350);

  Future<void> _onLoad(
    VisitsListLoadRequested event,
    Emitter<VisitsListState> emit,
  ) async {
    final started = DateTime.now();
    emit(state.copyWith(
      status: VisitsListStatus.loading,
      error: null,
    ));
    try {
      // Fetch everything the backend allows for this session and filter
      // client-side. Sends no date / employee scoping params on purpose —
      // see the class-level comment. `includeDrafts` is wired through
      // so admins also see the draft pipeline.
      final items =
          await repository.list(includeDrafts: event.includeDrafts);
      await _ensureMinSkeleton(started);
      emit(state.copyWith(
        status: VisitsListStatus.success,
        items: items,
        error: null,
      ));
    } on ApiException catch (e) {
      await _ensureMinSkeleton(started);
      emit(state.copyWith(status: VisitsListStatus.failure, error: e));
    }
  }

  Future<void> _ensureMinSkeleton(DateTime started) async {
    final elapsed = DateTime.now().difference(started);
    final remaining = _minSkeleton - elapsed;
    if (remaining > Duration.zero) await Future.delayed(remaining);
  }

  Future<void> _onFilterChanged(
    VisitsListFilterChanged event,
    Emitter<VisitsListState> emit,
  ) async {
    if (event.filter == state.filter) return;
    // No refetch — the page applies the filter on top of `state.items`.
    // When switching back to "Today" we also drop any admin slicers
    // (status/timing) that only make sense in the "All" view, so
    // they're not silently still applied next time.
    emit(state.copyWith(
      filter: event.filter,
      statusFilter: event.filter == VisitsFilter.today
          ? VisitStatusFilter.all
          : null,
      timingFilter: event.filter == VisitsFilter.today
          ? VisitTimingFilter.all
          : null,
    ));
  }
}
