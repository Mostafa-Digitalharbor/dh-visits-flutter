import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/di/service_locator.dart';
import '../data/models/visit.dart';
import '../data/visit_trail_tracker.dart';
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

  /// Injectable, and resolved from the locator only when registered — see the
  /// same field on [VisitDetailCubit] for why this isn't a bare `sl<>()` call.
  final VisitTrailTracker? _tracker;

  VisitTrailTracker? get _trail => _tracker ?? slMaybe<VisitTrailTracker>();

  VisitBloc({required this.repository, VisitTrailTracker? tracker})
      : _tracker = tracker,
        super(const VisitState()) {
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
      if (open.isEmpty) {
        // Nothing running: clear any tracking marker left by a visit that was
        // ended elsewhere, and flush whatever fixes it stranded on this device.
        await _trail?.resume(null);
        return;
      }
      emit(state.copyWith(
        status: VisitStatus.running,
        activeVisit: open.first,
      ));
      // The app was killed mid-visit (or is coming back from a cold start).
      // Pick the trail back up where it left off; the buffered fixes from the
      // previous run are still on disk waiting for this flush.
      await _trail?.resume(open.first.id);
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
