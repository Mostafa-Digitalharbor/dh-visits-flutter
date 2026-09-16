import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/constants.dart';
import '../data/models/visit.dart';
import '../data/visits_repository.dart';

part 'visits_list_event.dart';
part 'visits_list_state.dart';

/// Drives the visits list. `mine` is the field user's own visits (REST `/my`);
/// `pending` / `team` / `escalated` are manager slices read via `call_kw`
/// (Odoo record rules already scope them to the manager's hierarchy).
class VisitsListBloc extends Bloc<VisitsListEvent, VisitsListState> {
  final VisitsRepository repository;

  VisitsListBloc({required this.repository}) : super(VisitsListState.initial) {
    on<VisitsListLoadRequested>(_onLoad);
    on<VisitsListScopeChanged>(_onScopeChanged);
    on<VisitsListSearchChanged>(
      (e, emit) => emit(state.copyWith(searchQuery: e.query)),
    );
    // Picking a state or a tab is the user choosing a new slice, so a
    // dashboard preset that brought them here stops applying.
    on<VisitsListStateFilterChanged>(
      (e, emit) => emit(
        state.copyWith(
          stateFilter: e.state,
          clearStateFilter: e.state == null,
          focus: VisitsListFocus.all,
        ),
      ),
    );
    on<VisitsListFocusChanged>(
      (e, emit) => emit(state.copyWith(focus: e.focus, clearStateFilter: true)),
    );
    on<VisitsListReset>((_, emit) => emit(VisitsListState.initial));
  }

  /// Floor on how long the loading skeleton stays up, so a fast reply doesn't
  /// flash it for 80ms. Deliberately applied **only when a skeleton is actually
  /// on screen** — see [_ensureMinSkeleton].
  static const _minSkeleton = Duration(milliseconds: 350);

  Future<void> _onScopeChanged(
    VisitsListScopeChanged event,
    Emitter<VisitsListState> emit,
  ) async {
    if (event.scope == state.scope) return;
    emit(
      state.copyWith(
        scope: event.scope,
        clearStateFilter: true,
        focus: VisitsListFocus.all,
      ),
    );
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
    // A refresh over rows already on screen shows no skeleton, so there is
    // nothing to hold — padding it just made every pull-to-refresh 350ms
    // slower than the backend actually is.
    final showsSkeleton = state.items.isEmpty;
    emit(state.copyWith(status: VisitsListStatus.loading, error: null));
    try {
      final items = switch (scope) {
        VisitListScope.mine => await repository.myVisits(
          limit: AppConstants.visitsPageLimit,
        ),
        VisitListScope.pending => await repository.managerList(
          VisitManagerScope.pending,
        ),
        VisitListScope.team => await repository.managerList(
          VisitManagerScope.team,
        ),
        VisitListScope.escalated => await repository.managerList(
          VisitManagerScope.escalated,
        ),
      };
      await _ensureMinSkeleton(started, showsSkeleton);
      // A tab switched while this was in flight has its own fetch running;
      // these rows belong to the tab the user left.
      if (state.scope != scope) return;
      emit(state.copyWith(status: VisitsListStatus.success, items: items));
    } catch (e) {
      // Never leave the UI stuck on the loading skeleton — surface any
      // failure, including a response-parsing one, as a failure state.
      await _ensureMinSkeleton(started, showsSkeleton);
      if (state.scope != scope) return;
      emit(
        state.copyWith(
          status: VisitsListStatus.failure,
          error: e is ApiException ? e : ApiException.unexpected(e),
        ),
      );
    }
  }

  Future<void> _ensureMinSkeleton(DateTime started, bool showsSkeleton) async {
    if (!showsSkeleton) return;
    final remaining = _minSkeleton - DateTime.now().difference(started);
    if (remaining > Duration.zero) await Future.delayed(remaining);
  }
}
