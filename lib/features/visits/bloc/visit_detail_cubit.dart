import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/network/pending_actions_queue.dart';
import '../data/models/visit.dart';
import '../data/visits_repository.dart';

enum VisitDetailStatus { loading, ready, acting, error }

class VisitDetailState extends Equatable {
  final VisitDetailStatus status;
  final Visit? visit;
  final ApiException? error;

  /// Set once after a successful action so the UI can show a snackbar and
  /// (for terminal actions like end/cancel) pop back.
  final String? lastAction;

  const VisitDetailState({
    this.status = VisitDetailStatus.loading,
    this.visit,
    this.error,
    this.lastAction,
  });

  VisitDetailState copyWith({
    VisitDetailStatus? status,
    Visit? visit,
    ApiException? error,
    String? lastAction,
  }) =>
      VisitDetailState(
        status: status ?? this.status,
        visit: visit ?? this.visit,
        error: error,
        lastAction: lastAction,
      );

  @override
  List<Object?> get props => [status, visit, error, lastAction];
}

/// Loads a single visit in full detail and runs the workflow actions on it,
/// reloading after each so the header/buttons reflect the new state.
class VisitDetailCubit extends Cubit<VisitDetailState> {
  final VisitsRepository repository;
  final int visitId;

  VisitDetailCubit({required this.repository, required this.visitId})
      : super(const VisitDetailState());

  Future<void> load() async {
    emit(state.copyWith(status: VisitDetailStatus.loading, error: null));
    try {
      // Prefer the rich call_kw read (managers, participants, history, GPS).
      final visit = await repository.readVisitFull(visitId);
      if (visit != null) {
        emit(VisitDetailState(status: VisitDetailStatus.ready, visit: visit));
        return;
      }
      // Fall back to the slim REST /api/visit/get payload if the full read
      // returned nothing (e.g. call_kw restricted for this user).
      final slim = await repository.getVisit(visitId);
      emit(VisitDetailState(status: VisitDetailStatus.ready, visit: slim));
    } on ApiException catch (e) {
      // Last resort: try the REST endpoint before surfacing the error.
      try {
        final slim = await repository.getVisit(visitId);
        if (slim != null) {
          emit(VisitDetailState(status: VisitDetailStatus.ready, visit: slim));
          return;
        }
      } catch (_) {}
      emit(state.copyWith(status: VisitDetailStatus.error, error: e));
    }
  }

  Future<bool> _run(String action, Future<void> Function() body) async {
    emit(state.copyWith(status: VisitDetailStatus.acting, error: null));
    try {
      await body();
      final visit = await repository.readVisitFull(visitId);
      emit(VisitDetailState(
        status: VisitDetailStatus.ready,
        visit: visit,
        lastAction: action,
      ));
      return true;
    } on ApiException catch (e) {
      // Reload so the header stays truthful even after a failed action.
      final visit = await _safeReload();
      emit(VisitDetailState(
        status: VisitDetailStatus.ready,
        visit: visit ?? state.visit,
        error: e,
      ));
      return false;
    } catch (e) {
      final visit = await _safeReload();
      emit(VisitDetailState(
        status: VisitDetailStatus.ready,
        visit: visit ?? state.visit,
        error: ApiException.unknown(e.toString()),
      ));
      return false;
    }
  }

  Future<Visit?> _safeReload() async {
    try {
      return await repository.readVisitFull(visitId);
    } catch (_) {
      return null;
    }
  }

  Future<bool> submit() => _run('submit', () => repository.submit(visitId));

  Future<bool> approve() => _run('approve', () => repository.approve(visitId));

  Future<bool> reject(String reason) =>
      _run('reject', () => repository.reject(visitId, reason));

  Future<bool> cancel() => _run('cancel', () => repository.cancel(visitId));

  Future<bool> reschedule({
    DateTime? scheduledDatetime,
    String? purpose,
    String? location,
  }) =>
      _run(
        'reschedule',
        () => repository.reschedule(
          visitId,
          scheduledDatetime: scheduledDatetime,
          purpose: purpose,
          location: location,
        ),
      );

  Future<bool> start({double? latitude, double? longitude}) => _runQueueable(
        'start',
        {'type': 'start', 'latitude': latitude, 'longitude': longitude},
        () => repository.start(visitId,
            latitude: latitude, longitude: longitude),
      );

  Future<bool> end({
    required String outcome,
    double? latitude,
    double? longitude,
  }) =>
      _runQueueable(
        'end',
        {
          'type': 'end',
          'outcome': outcome,
          'latitude': latitude,
          'longitude': longitude,
        },
        () => repository.end(visitId,
            outcome: outcome, latitude: latitude, longitude: longitude),
      );

  /// Like [_run] but for the GPS-stamped Start / End actions: if the network is
  /// down we persist the action to the offline queue and report a soft success
  /// (`<action>_queued`) instead of an error, so a field rep in a dead zone can
  /// keep working. The queue replays it automatically when connectivity is back.
  Future<bool> _runQueueable(
    String action,
    Map<String, dynamic> payload,
    Future<void> Function() body,
  ) async {
    emit(state.copyWith(status: VisitDetailStatus.acting, error: null));
    try {
      await body();
      final visit = await repository.readVisitFull(visitId);
      emit(VisitDetailState(
        status: VisitDetailStatus.ready,
        visit: visit,
        lastAction: action,
      ));
      return true;
    } on ApiException catch (e) {
      if (e.code == ApiErrorCode.network || e.code == ApiErrorCode.timeout) {
        await sl<PendingActionsQueue>().enqueue(visitId, payload);
        emit(state.copyWith(
          status: VisitDetailStatus.ready,
          lastAction: '${action}_queued',
        ));
        return true;
      }
      final visit = await _safeReload();
      emit(VisitDetailState(
        status: VisitDetailStatus.ready,
        visit: visit ?? state.visit,
        error: e,
      ));
      return false;
    } catch (e) {
      final visit = await _safeReload();
      emit(VisitDetailState(
        status: VisitDetailStatus.ready,
        visit: visit ?? state.visit,
        error: ApiException.unknown(e.toString()),
      ));
      return false;
    }
  }

  Future<bool> addParticipants(List<int> employeeIds) => _run(
        'add_participants',
        () => repository.addParticipants(visitId, employeeIds),
      );

  Future<bool> approveParticipant(int participantId) => _run(
        'participant_approve',
        () => repository.approveParticipant(participantId),
      );

  Future<bool> rejectParticipant(int participantId, String reason) => _run(
        'participant_reject',
        () => repository.rejectParticipant(participantId, reason),
      );

  Future<bool> uploadAttachment({
    required String filename,
    required String dataB64,
  }) =>
      _run(
        'attachment',
        () => repository.uploadAttachment(visitId,
            filename: filename, dataB64: dataB64),
      );
}
