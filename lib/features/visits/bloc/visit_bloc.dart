import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/network/pending_actions_queue.dart';
import '../../../core/utils/app_log.dart';
import '../data/models/visit.dart';
import '../data/visit_trail_tracker.dart';
import '../data/visits_repository.dart';

part 'visit_event.dart';
part 'visit_state.dart';

/// Tracks the single visit that is currently **in progress** (started, not yet
/// ended) so the persistent bar stays in sync, and hands the server's answer
/// to [VisitTrailTracker] so trail recording is restored only for a visit the
/// server still has running.
///
/// Starting and ending a visit live in [VisitDetailCubit].
class VisitBloc extends Bloc<VisitEvent, VisitState> {
  final VisitsRepository repository;

  /// Injectable, and resolved from the locator only when registered — see the
  /// same field on [VisitDetailCubit] for why this isn't a bare `sl<>()` call.
  final VisitTrailTracker? _tracker;
  final PendingActionsQueue? _queue;

  VisitTrailTracker? get _trail => _tracker ?? slMaybe<VisitTrailTracker>();
  PendingActionsQueue? get _pending => _queue ?? slMaybe<PendingActionsQueue>();

  VisitBloc({
    required this.repository,
    VisitTrailTracker? tracker,
    PendingActionsQueue? pendingActions,
  }) : _tracker = tracker,
       _queue = pendingActions,
       super(const VisitState()) {
    on<VisitResumeRequested>(_onResume);
    on<VisitStarted>((event, emit) => emit(VisitState.running(event.visit)));
    on<VisitCleared>((event, emit) => emit(const VisitState()));
  }

  Future<void> _onResume(
    VisitResumeRequested event,
    Emitter<VisitState> emit,
  ) async {
    final trail = _trail;
    final Visit? running;
    try {
      running = await repository.myRunningVisit();
    } catch (e) {
      // Offline (or the read failed): the bar stays as it is, and recording
      // continues only for the visit this device was already recording — the
      // tracker asks the server again once the network is back.
      appLog('[VisitBloc] resume failed: $e');
      await _guard(() async => trail?.resumeUnverified());
      return;
    }
    if (running != null) {
      emit(VisitState.running(running));
    } else if (state.status == VisitStatus.running &&
        !_hasQueuedAction(state.activeVisit?.id)) {
      // Ended or cancelled elsewhere. A visit whose Start is still queued
      // offline keeps its bar: the server has not heard of it yet.
      emit(const VisitState());
    }
    // Recording follows the server: the running visit (unless its End is
    // queued), or nothing — which also stops a capture a previous process left
    // running and uploads what it stranded on this device.
    await _guard(() async => trail?.resume(running));
  }

  bool _hasQueuedAction(int? visitId) {
    if (visitId == null) return false;
    try {
      return _pending?.pending.any((a) => a.visitId == visitId) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Best-effort: nothing to show the user on failure, and a tracker error must
  /// not escape to the bloc's error handler.
  Future<void> _guard(Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      appLog('[VisitBloc] trail restore failed: $e');
    }
  }
}
