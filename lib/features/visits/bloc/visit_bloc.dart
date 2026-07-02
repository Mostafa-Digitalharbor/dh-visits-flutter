import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/location/location_service.dart';
import '../data/models/visit.dart';
import '../data/models/visit.dart' as vm show VisitState;
import '../data/visits_repository.dart';

part 'visit_event.dart';
part 'visit_state.dart';

/// Tracks the single visit that is currently **in progress** (started with GPS,
/// not yet ended) so the persistent bar and Start/End buttons stay in sync.
class VisitBloc extends Bloc<VisitEvent, VisitState> {
  final VisitsRepository repository;
  final LocationService locationService;

  VisitBloc({required this.repository, required this.locationService})
      : super(const VisitState()) {
    on<VisitStartRequested>(_onStart);
    on<VisitEndRequested>(_onEnd);
    on<VisitResumeRequested>(_onResume);
    on<VisitCleared>((event, emit) => emit(const VisitState()));
  }

  Future<void> _onStart(
    VisitStartRequested event,
    Emitter<VisitState> emit,
  ) async {
    if (state.status == VisitStatus.running) return; // one running visit at a time
    emit(state.copyWith(status: VisitStatus.submitting, error: null));
    try {
      final ok = await locationService.ensurePermission();
      if (!ok) {
        emit(state.copyWith(
          status: VisitStatus.idle,
          error: ApiException(code: ApiErrorCode.locationPermission),
        ));
        return;
      }
      final pos = await locationService.getCurrent();
      await repository.start(
        event.visit.id,
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
      // Reflect the new state locally; the bar reads startDatetime for its timer.
      final running = event.visit.copyWith(
        state: vm.VisitState.inProgress,
        startDatetime: DateTime.now().toUtc(),
      );
      emit(state.copyWith(status: VisitStatus.running, activeVisit: running));
    } on ApiException catch (e) {
      emit(state.copyWith(status: VisitStatus.idle, error: e));
    } catch (e) {
      emit(state.copyWith(
        status: VisitStatus.idle,
        error: ApiException.unknown(e.toString()),
      ));
    }
  }

  Future<void> _onEnd(
    VisitEndRequested event,
    Emitter<VisitState> emit,
  ) async {
    emit(state.copyWith(status: VisitStatus.submitting, error: null));
    try {
      final ok = await locationService.ensurePermission();
      if (!ok) {
        emit(state.copyWith(
          status: VisitStatus.running,
          error: ApiException(code: ApiErrorCode.locationPermission),
        ));
        return;
      }
      final pos = await locationService.getCurrent();
      await repository.end(
        event.visitId,
        outcome: event.outcome,
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
      emit(const VisitState(status: VisitStatus.ended));
    } on ApiException catch (e) {
      emit(state.copyWith(status: VisitStatus.running, error: e));
    } catch (e) {
      emit(state.copyWith(
        status: VisitStatus.running,
        error: ApiException.unknown(e.toString()),
      ));
    }
  }

  Future<void> _onResume(
    VisitResumeRequested event,
    Emitter<VisitState> emit,
  ) async {
    if (state.status == VisitStatus.running) return;
    try {
      final open = await repository.myVisits(
        domain: [
          ['state', '=', 'in_progress'],
        ],
        limit: 1,
      );
      if (open.isEmpty) return;
      emit(state.copyWith(
        status: VisitStatus.running,
        activeVisit: open.first,
      ));
    } on ApiException {
      // Silent — recovery is best-effort.
    }
  }
}
