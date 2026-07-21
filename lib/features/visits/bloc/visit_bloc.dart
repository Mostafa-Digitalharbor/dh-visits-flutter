import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/api/api_exceptions.dart';
import '../data/models/visit.dart';
import '../data/visits_repository.dart';
import '../../../core/utils/app_log.dart';

part 'visit_event.dart';
part 'visit_state.dart';

/// Tracks the single visit that is currently **in progress** (started with GPS,
/// not yet ended) so the persistent bar stays in sync.
///
/// Starting and ending a visit live in [VisitDetailCubit] — this bloc used to
/// carry a second, never-dispatched implementation of both, which had already
/// drifted from the real one (no mock-GPS check, no offline queue).
class VisitBloc extends Bloc<VisitEvent, VisitState> {
  final VisitsRepository repository;

  VisitBloc({required this.repository}) : super(const VisitState()) {
    on<VisitResumeRequested>(_onResume);
    on<VisitCleared>((event, emit) => emit(const VisitState()));
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
    } catch (e) {
      // Also silent, but it must be *caught*: a parse failure here throws a
      // TypeError rather than an ApiException, which would escape to the bloc
      // error handler. The rep would lose their running-visit bar (and the
      // quick path to End) with nothing explaining why.
      appLog('[VisitBloc] resume failed: $e');
    }
  }
}
