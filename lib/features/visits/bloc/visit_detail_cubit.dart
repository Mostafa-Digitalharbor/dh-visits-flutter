import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/network/pending_actions_queue.dart';
import '../data/models/visit.dart';
import '../data/models/visit_attachment.dart';
import '../data/visit_trail_tracker.dart';
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

  /// Collects the GPS trail between Start and End. Injectable, and resolved
  /// from the locator only when it is actually registered: a cubit under test
  /// exercises the workflow without a tracker, and a hard `sl<>()` lookup in
  /// [start] / [end] threw `GetIt: not registered` before either action ran.
  final VisitTrailTracker? _tracker;

  VisitDetailCubit({
    required this.repository,
    required this.visitId,
    VisitTrailTracker? tracker,
  })  : _tracker = tracker,
        super(const VisitDetailState());

  VisitTrailTracker? get _trail => _tracker ?? slMaybe<VisitTrailTracker>();

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
      if (slim == null) {
        // Both reads came back empty. Neither throws on a missing record —
        // `_rows()` degrades any non-List result to `[]`, and `getVisit`
        // degrades a non-Map to null — so without this the cubit would emit
        // `ready` with a null visit and the view would sit on a bare spinner
        // with no error, no retry and no pull-to-refresh, forever. Reachable
        // by opening a deleted visit from the notifications feed.
        _safeEmit(state.copyWith(
          status: VisitDetailStatus.error,
          error: ApiException(code: ApiErrorCode.notFound),
        ));
        return;
      }
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
    } catch (e) {
      // Never leave the UI stuck on the loading skeleton. A schema change or an
      // Odoo field serialised as `false` throws a TypeError, not an
      // ApiException, and would otherwise escape the handler above and freeze
      // the screen. Every sibling bloc has this arm; this one was the gap.
      _safeEmit(state.copyWith(
        status: VisitDetailStatus.error,
        error: ApiException.unexpected(e),
      ));
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

  /// True while a workflow action is already in flight. Every action is
  /// fire-and-forget from an `onPressed`, so without this a second tap starts a
  /// second request — and the loser of that race overwrites the winner's state.
  bool get _busy => state.status == VisitDetailStatus.acting;

  Future<bool> _run(String action, Future<void> Function() body) async {
    if (_busy) return false;
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
      await _emitFailure(e);
      return false;
    } catch (e) {
      await _emitFailure(ApiException.unexpected(e));
      return false;
    }
  }

  /// Settles back to `ready` with [error] attached, after re-reading the visit
  /// so the header and action bar stay truthful even though the action failed.
  ///
  /// Both action runners have an `ApiException` arm and a catch-all arm, and
  /// each used to spell this state out by hand — four copies of the same
  /// six-field constructor. They are easy to write *almost* right: dropping
  /// `mockFlagged` from one of them silently clears a spoofing warning, which
  /// is exactly the kind of bug a reviewer does not catch by eye.
  Future<void> _emitFailure(ApiException error) async {
    final visit = await _safeReload();
    _safeEmit(VisitDetailState(
      status: VisitDetailStatus.ready,
      visit: visit ?? state.visit,
      error: error,
      attachments: state.attachments,
      mockFlagged: state.mockFlagged,
    ));
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
  }) async {
    final ok = await _runQueueable(
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
    // The trail starts the moment the visit does — including when the Start
    // itself only reached the offline queue. The fixes buffer on the device and
    // upload once the queued Start has replayed, which is the whole reason the
    // tracker checks that queue before it flushes.
    if (ok) unawaited(_trail?.start(visitId) ?? Future<void>.value());
    return ok;
  }

  /// See [start] on why the coordinates are required.
  Future<bool> end({
    required String outcome,
    required double latitude,
    required double longitude,
    String? location,
    bool isMocked = false,
  }) async {
    if (_busy) return false;
    final tracker = _trail;
    // Push what is still buffered *before* the visit closes. A late flush is
    // supported — the server accepts a point transmitted after the end as long
    // as its `logged_at` falls inside the start–end window — but the End also
    // stamps `end_datetime`, so anything sampled during the request itself
    // would land outside it and be refused for good.
    await tracker?.flushNow();
    final ok = await _runQueueable(
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
    if (ok) await tracker?.stop();
    return ok;
  }

  /// Like [_run] but for the GPS-stamped Start / End actions: if the network is
  /// down we persist the action to the offline queue and report a soft success
  /// (`<action>_queued`) instead of an error, so a field rep in a dead zone can
  /// keep working. The queue replays it automatically when connectivity is back.
  Future<bool> _runQueueable(
    String action,
    Map<String, dynamic> payload,
    Future<void> Function() body,
  ) async {
    if (_busy) return false;
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
        // The enqueue needs its own guard: it sits inside a catch block, so a
        // SharedPreferences write failure (storage full, channel error) would
        // escape _runQueueable entirely, leaving status stuck on `acting` — the
        // full-screen busy overlay spinning forever, with the action lost and
        // nothing said about it.
        try {
          await sl<PendingActionsQueue>().enqueue(visitId, payload);
        } catch (queueError) {
          await _emitFailure(ApiException.unexpected(queueError));
          return false;
        }
        // Advance the local state to match what was queued. Without this the
        // visit still reads `approved` after an offline Start, so the action
        // bar keeps offering Start and never offers End (`canEnd` requires
        // `inProgress`) — a rep who starts a visit in a dead zone could not
        // finish it until connectivity returned, which is the exact situation
        // the queue exists to cover.
        final queuedType = payload['type']?.toString();
        final optimistic = switch (queuedType) {
          'start' => state.visit?.copyWith(
              state: VisitState.inProgress,
              startDatetime: DateTime.now(),
            ),
          'end' => state.visit?.copyWith(
              state: VisitState.done,
              endDatetime: DateTime.now(),
              outcome: payload['outcome']?.toString(),
            ),
          _ => state.visit,
        };
        _safeEmit(state.copyWith(
          status: VisitDetailStatus.ready,
          visit: optimistic,
          lastAction: '${action}_queued',
          // Queued offline: the note has not been posted yet, but the verdict
          // is already known locally, so warn now rather than after the sync.
          mockFlagged: state.mockFlagged || payload['is_mocked'] == true,
        ));
        return true;
      }
      await _emitFailure(e);
      return false;
    } catch (e) {
      await _emitFailure(ApiException.unexpected(e));
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
