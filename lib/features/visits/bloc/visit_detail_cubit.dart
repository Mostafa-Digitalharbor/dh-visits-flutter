import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/network/pending_actions_queue.dart';
import '../data/models/visit.dart';
import '../data/models/visit_attachment.dart';
import '../data/visits_repository.dart';

enum VisitDetailStatus { loading, ready, acting, error }

class VisitDetailState extends Equatable {
  final VisitDetailStatus status;
  final Visit? visit;
  final ApiException? error;

  /// Set once after a successful action so the UI can show a snackbar and
  /// (for terminal actions like end/cancel) pop back.
  final String? lastAction;

  /// Attachments live in state rather than being fetched by the view: built as
  /// a `FutureBuilder` whose future was created inside `build()`, they were
  /// re-fetched from Odoo on every single rebuild.
  final List<VisitAttachment> attachments;

  /// Attachments fail independently of the visit — a read error here must not
  /// blank the whole screen, so it's tracked separately from [error].
  final ApiException? attachmentsError;

  /// True when a mock-location (fake-GPS) verdict was recorded against this
  /// visit. Lives on the chatter rather than a field on `dh.visit` — see
  /// `VisitsRepository.hasMockLocationFlag`.
  final bool mockFlagged;

  const VisitDetailState({
    this.status = VisitDetailStatus.loading,
    this.visit,
    this.error,
    this.lastAction,
    this.attachments = const [],
    this.attachmentsError,
    this.mockFlagged = false,
  });

  /// Note: [error] and [lastAction] are deliberately *not* `?? this.x`. They're
  /// one-shot signals (show a snackbar once) and must clear on the next emit,
  /// unlike [visit] / [attachments], which persist until refetched.
  VisitDetailState copyWith({
    VisitDetailStatus? status,
    Visit? visit,
    ApiException? error,
    String? lastAction,
    List<VisitAttachment>? attachments,
    ApiException? attachmentsError,
    bool? mockFlagged,
  }) =>
      VisitDetailState(
        status: status ?? this.status,
        visit: visit ?? this.visit,
        error: error,
        lastAction: lastAction,
        attachments: attachments ?? this.attachments,
        attachmentsError: attachmentsError,
        // Sticky like [visit]: once raised, a flag must not vanish because some
        // later partial emit forgot to carry it.
        mockFlagged: mockFlagged ?? this.mockFlagged,
      );

  @override
  List<Object?> get props => [
        status,
        visit,
        error,
        lastAction,
        attachments,
        attachmentsError,
        mockFlagged,
      ];
}

/// Loads a single visit in full detail and runs the workflow actions on it,
/// reloading after each so the header/buttons reflect the new state.
class VisitDetailCubit extends Cubit<VisitDetailState> {
  final VisitsRepository repository;
  final int visitId;

  VisitDetailCubit({required this.repository, required this.visitId})
      : super(const VisitDetailState());

  /// Guards every post-`await` emit. Each action here is fire-and-forget from
  /// an `onPressed`, so the user can pop the page (disposing the cubit) while
  /// the request is still in flight — and `emit` on a closed cubit throws a
  /// `StateError` that surfaces as an unhandled async error.
  void _safeEmit(VisitDetailState next) {
    if (isClosed) return;
    emit(next);
  }

  Future<void> load() async {
    _safeEmit(state.copyWith(status: VisitDetailStatus.loading, error: null));
    try {
      // Prefer the rich call_kw read (managers, participants, history, GPS).
      // Attachments are fetched alongside it rather than after, so the extra
      // round-trip doesn't delay the screen.
      final visitFuture = repository.readVisitFull(visitId);
      final attachmentsFuture = _readAttachments();
      // Fired alongside the others so the spoofing check costs no extra wait.
      final mockFuture = repository.hasMockLocationFlag(visitId);
      final visit = await visitFuture;
      final (attachments, attachmentsError) = await attachmentsFuture;
      final mockFlagged = await mockFuture;

      if (visit != null) {
        _safeEmit(VisitDetailState(
          status: VisitDetailStatus.ready,
          visit: visit,
          attachments: attachments,
          attachmentsError: attachmentsError,
          mockFlagged: mockFlagged,
        ));
        return;
      }
      // Fall back to the slim REST /api/visit/get payload if the full read
      // returned nothing (e.g. call_kw restricted for this user).
      final slim = await repository.getVisit(visitId);
      _safeEmit(VisitDetailState(
        status: VisitDetailStatus.ready,
        visit: slim,
        attachments: attachments,
        attachmentsError: attachmentsError,
        mockFlagged: mockFlagged,
      ));
    } on ApiException catch (e) {
      // Last resort: try the REST endpoint before surfacing the error.
      try {
        final slim = await repository.getVisit(visitId);
        if (slim != null) {
          _safeEmit(
              VisitDetailState(status: VisitDetailStatus.ready, visit: slim));
          return;
        }
      } catch (_) {}
      _safeEmit(state.copyWith(status: VisitDetailStatus.error, error: e));
    }
  }

  /// Reads attachments without letting their failure take down the visit: the
  /// error is returned for the section to render in place.
  Future<(List<VisitAttachment>, ApiException?)> _readAttachments() async {
    try {
      return (await repository.readAttachments(visitId), null);
    } on ApiException catch (e) {
      return (const <VisitAttachment>[], e);
    } catch (e) {
      return (const <VisitAttachment>[], ApiException.unexpected(e));
    }
  }

  Future<bool> _run(String action, Future<void> Function() body) async {
    _safeEmit(state.copyWith(status: VisitDetailStatus.acting, error: null));
    try {
      await body();
      final (visit, attachments, attachmentsError) = await _reload();
      _safeEmit(VisitDetailState(
        status: VisitDetailStatus.ready,
        visit: visit,
        lastAction: action,
        attachments: attachments,
        attachmentsError: attachmentsError,
        // These emits build a fresh state rather than copyWith, so every one of
        // them has to carry the flag forward explicitly — otherwise approving a
        // visit would quietly clear a spoofing warning raised at check-in.
        mockFlagged: state.mockFlagged,
      ));
      return true;
    } on ApiException catch (e) {
      // Reload so the header stays truthful even after a failed action.
      final visit = await _safeReload();
      _safeEmit(VisitDetailState(
        status: VisitDetailStatus.ready,
        visit: visit ?? state.visit,
        error: e,
        attachments: state.attachments,
        mockFlagged: state.mockFlagged,
      ));
      return false;
    } catch (e) {
      final visit = await _safeReload();
      _safeEmit(VisitDetailState(
        status: VisitDetailStatus.ready,
        visit: visit ?? state.visit,
        error: ApiException.unexpected(e),
        attachments: state.attachments,
        mockFlagged: state.mockFlagged,
      ));
      return false;
    }
  }

  /// Re-reads the visit and its attachments together after an action. Uploads
  /// change the attachment list, and any action can change the visit, so both
  /// are refreshed in parallel.
  Future<(Visit?, List<VisitAttachment>, ApiException?)> _reload() async {
    final visitFuture = repository.readVisitFull(visitId);
    final attachmentsFuture = _readAttachments();
    final visit = await visitFuture;
    final (attachments, attachmentsError) = await attachmentsFuture;
    return (visit, attachments, attachmentsError);
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

  /// Coordinates are required, not optional: a visit is GPS evidence, and
  /// these used to be nullable, so a denied permission or a cancelled
  /// mock-location warning silently started a visit with no location at all.
  /// Callers must resolve a real position first (see `LocationOutcome`).
  /// [location] is the reverse-geocoded label stored as `start_location`, and
  /// [isMocked] the OS mock-provider verdict. Both travel in the queue payload
  /// too — an action replayed hours later must carry the same evidence as one
  /// sent live, or going offline would become a way to launder a spoofed fix.
  Future<bool> start({
    required double latitude,
    required double longitude,
    String? location,
    bool isMocked = false,
  }) =>
      _runQueueable(
        'start',
        {
          'type': 'start',
          'latitude': latitude,
          'longitude': longitude,
          if (location != null) 'location': location,
          if (isMocked) 'is_mocked': true,
        },
        () => repository.start(visitId,
            latitude: latitude,
            longitude: longitude,
            location: location,
            isMocked: isMocked),
      );

  /// See [start] on why the coordinates are required.
  Future<bool> end({
    required String outcome,
    required double latitude,
    required double longitude,
    String? location,
    bool isMocked = false,
  }) =>
      _runQueueable(
        'end',
        {
          'type': 'end',
          'outcome': outcome,
          'latitude': latitude,
          'longitude': longitude,
          if (location != null) 'location': location,
          if (isMocked) 'is_mocked': true,
        },
        () => repository.end(visitId,
            outcome: outcome,
            latitude: latitude,
            longitude: longitude,
            location: location,
            isMocked: isMocked),
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
    _safeEmit(state.copyWith(status: VisitDetailStatus.acting, error: null));
    try {
      await body();
      final (visit, attachments, attachmentsError) = await _reload();
      // Re-read rather than carry forward: unlike the other actions, Start and
      // End are the two that can *raise* the flag, and they do it server-side
      // inside `body()`. The payload's own `is_mocked` is not consulted here so
      // the banner reflects what is actually on the record.
      final mockFlagged = await repository.hasMockLocationFlag(visitId);
      _safeEmit(VisitDetailState(
        status: VisitDetailStatus.ready,
        visit: visit,
        lastAction: action,
        attachments: attachments,
        attachmentsError: attachmentsError,
        mockFlagged: mockFlagged,
      ));
      return true;
    } on ApiException catch (e) {
      if (e.code == ApiErrorCode.network || e.code == ApiErrorCode.timeout) {
        await sl<PendingActionsQueue>().enqueue(visitId, payload);
        _safeEmit(state.copyWith(
          status: VisitDetailStatus.ready,
          lastAction: '${action}_queued',
          // Queued offline: the note has not been posted yet, but the verdict
          // is already known locally, so warn now rather than after the sync.
          mockFlagged: state.mockFlagged || payload['is_mocked'] == true,
        ));
        return true;
      }
      final visit = await _safeReload();
      _safeEmit(VisitDetailState(
        status: VisitDetailStatus.ready,
        visit: visit ?? state.visit,
        error: e,
        attachments: state.attachments,
        mockFlagged: state.mockFlagged,
      ));
      return false;
    } catch (e) {
      final visit = await _safeReload();
      _safeEmit(VisitDetailState(
        status: VisitDetailStatus.ready,
        visit: visit ?? state.visit,
        error: ApiException.unexpected(e),
        attachments: state.attachments,
        mockFlagged: state.mockFlagged,
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
