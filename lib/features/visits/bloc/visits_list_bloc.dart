import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/api/api_exceptions.dart';
import '../data/models/visit.dart';
import '../data/visits_repository.dart';
import '../../../core/constants.dart';

part 'visits_list_event.dart';
part 'visits_list_state.dart';

/// Drives the visits list. `mine` is the field user's own visits (REST `/my`);
/// `pending` / `team` / `escalated` are manager slices read via `call_kw`
/// (Odoo record rules already scope them to the manager's hierarchy).
class VisitsListBloc extends Bloc<VisitsListEvent, VisitsListState> {
  final VisitsRepository repository;

  VisitsListBloc({required this.repository}) : super(const VisitsListState()) {
    on<VisitsListLoadRequested>(_onLoad);
    on<VisitsListScopeChanged>(_onScopeChanged);
    on<VisitsListSearchChanged>(
        (e, emit) => emit(state.copyWith(searchQuery: e.query)));
    on<VisitsListStateFilterChanged>((e, emit) => emit(state.copyWith(
        stateFilter: e.state, clearStateFilter: e.state == null)));
    on<VisitsListReset>((_, emit) => emit(const VisitsListState()));
  }

  static const _minSkeleton = Duration(milliseconds: 350);

  Future<void> _onScopeChanged(
    VisitsListScopeChanged event,
    Emitter<VisitsListState> emit,
  ) async {
    if (event.scope == state.scope) return;
    emit(state.copyWith(scope: event.scope, clearStateFilter: true));
    await _fetch(event.scope, emit);
  }

  Future<void> _onLoad(
    VisitsListLoadRequested event,
    Emitter<VisitsListState> emit,
  ) async {
    final scope = event.scope ?? state.scope;
    if (event.scope != null && event.scope != state.scope) {
      emit(state.copyWith(scope: scope));
    }
    await _fetch(scope, emit);
  }

  Future<void> _fetch(
    VisitListScope scope,
    Emitter<VisitsListState> emit,
  ) async {
    final started = DateTime.now();
    emit(state.copyWith(status: VisitsListStatus.loading, error: null));
    try {
      final items = switch (scope) {
        VisitListScope.mine => await repository.myVisits(limit: AppConstants.visitsPageLimit),
        VisitListScope.pending =>
          await repository.managerList(VisitManagerScope.pending),
        VisitListScope.team =>
          await repository.managerList(VisitManagerScope.team),
        VisitListScope.escalated =>
          await repository.managerList(VisitManagerScope.escalated),
      };
      await _ensureMinSkeleton(started);
      emit(state.copyWith(status: VisitsListStatus.success, items: items));
    } on ApiException catch (e) {
      await _ensureMinSkeleton(started);
      emit(state.copyWith(status: VisitsListStatus.failure, error: e));
    } catch (e) {
      // Never leave the UI stuck on the loading skeleton — surface any
      // unexpected error (e.g. a response-parsing failure) as a failure state.
      await _ensureMinSkeleton(started);
      emit(state.copyWith(
        status: VisitsListStatus.failure,
        error: ApiException.unexpected(e),
      ));
    }
  }

  Future<void> _ensureMinSkeleton(DateTime started) async {
    final remaining = _minSkeleton - DateTime.now().difference(started);
    if (remaining > Duration.zero) await Future.delayed(remaining);
  }
}
