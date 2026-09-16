import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/network/pending_actions_queue.dart';
import '../../../core/network/server_clock.dart';
import '../../../core/utils/app_log.dart';
import '../data/models/visit.dart';
import '../data/models/visit_attachment.dart';
import '../data/visit_trail_tracker.dart';
import '../data/visits_repository.dart';
import '../domain/visit_action.dart';

enum VisitDetailStatus { loading, ready, acting, error }

class VisitDetailState extends Equatable {
  final VisitDetailStatus status;
  final Visit? visit;
  final ApiException? error;

  /// Set once after a successful action so the UI can show a snackbar and
  /// (for terminal actions like end/cancel) pop back.
  final VisitActionOutcome? lastAction;

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
    VisitActionOutcome? lastAction,
    List<VisitAttachment>? attachments,
    ApiException? attachmentsError,
    bool? mockFlagged,
  }) => VisitDetailState(
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

  /// Holds Start / End while offline. Same injection rule as [_tracker].
  final PendingActionsQueue? _queue;

  VisitDetailCubit({
    required this.repository,
    required this.visitId,
    VisitTrailTracker? tracker,
    PendingActionsQueue? pendingActions,
  }) : _tracker = tracker,
       _queue = pendingActions,
       super(const VisitDetailState());

  VisitTrailTracker? get _trail => _tracker ?? slMaybe<VisitTrailTracker>();

  PendingActionsQueue? get _pending => _queue ?? slMaybe<PendingActionsQueue>();

  /// Guards every post-`await` emit. Each action here is fire-and-forget from
  /// an `onPressed`, so the user can pop the page (disposing the cubit) while
  /// the request is still in flight — and `emit` on a closed cubit throws a
  /// `StateError` that surfaces as an unhandled async error.
  void _safeEmit(VisitDetailState next) {
    if (isClosed) return;
    emit(next);
  }

  /// Loads the visit, its attachments and its mock-location flag together.
  ///
  /// Skipped while an action runs: a pull-to-refresh landing mid-action used
  /// to drop the `acting` status, which is what keeps a second tap out.
  Future<void> load() async {
    if (_busy) return;
    _safeEmit(state.copyWith(status: VisitDetailStatus.loading));
    // Fired alongside the visit read so neither costs the screen extra time.
    final attachmentsFuture = _readAttachments();
    final mockFuture = repository.hasMockLocationFlag(visitId);

    final (visit, failure) = await _readVisit();
    final (attachments, attachmentsError) = await attachmentsFuture;
    final mockFlagged = await mockFuture;

    if (visit == null) {
      // Neither read throws on a missing record — `_rows()` degrades any
      // non-List result to `[]`, and `getVisit` degrades a non-Map to null —
      // so without the notFound fallback the view would sit on a bare spinner
      // with no error and no retry. Reachable by opening a deleted visit from
      // the notifications feed.
      _safeEmit(
        state.copyWith(
          status: VisitDetailStatus.error,
          error: failure ?? ApiException(code: ApiErrorCode.notFound),
        ),
      );
      return;
    }
    _reconcileTrail(visit);
    _safeEmit(
      VisitDetailState(
        status: VisitDetailStatus.ready,
        visit: visit,
        attachments: attachments,
        attachmentsError: attachmentsError,
        mockFlagged: state.mockFlagged || mockFlagged,
      ),
    );
  }

  /// Stops recording this visit's trail once the server shows it is no longer
  /// in progress — cancelled, rescheduled, ended on another device. Never
  /// starts recording: only a confirmed Start does that.
  void _reconcileTrail(Visit? visit) {
    final tracker = _trail;
    if (visit == null || tracker == null) return;
    if (tracker.activeVisitId != visitId || visit.isInProgress) return;
    appLog(
      '[VisitDetailCubit] visit $visitId is ${visit.state.name}; '
      'stopping its trail',
    );
    unawaited(_guardTrail('stop', tracker.stop));
  }

  /// The rich `call_kw` read (managers, participants, history, GPS), falling
  /// back to the slim REST payload when that returns nothing or fails — e.g.
  /// a user whose `call_kw` access is restricted. Never throws: the first
  /// failure comes back for the caller to show when both reads miss.
  Future<(Visit?, ApiException?)> _readVisit() async {
    ApiException? failure;
    try {
      final full = await repository.readVisitFull(visitId);
      if (full != null) return (full, null);
    } catch (e) {
      failure = _asApiException(e);
    }
    try {
      return (await repository.getVisit(visitId), failure);
    } catch (e) {
      return (null, failure ?? _asApiException(e));
    }
  }

  /// Reads attachments without letting their failure take down the visit: the
  /// error is returned for the section to render in place.
  Future<(List<VisitAttachment>, ApiException?)> _readAttachments() async {
    try {
      return (await repository.readAttachments(visitId), null);
    } catch (e) {
      return (const <VisitAttachment>[], _asApiException(e));
    }
  }

  static ApiException _asApiException(Object error) =>
      error is ApiException ? error : ApiException.unexpected(error);

  /// True while a workflow action is already in flight. Every action is
  /// fire-and-forget from an `onPressed`, so without this a second tap starts a
  /// second request — and the loser of that race overwrites the winner's state.
  bool get _busy => state.status == VisitDetailStatus.acting;

  /// Marks an action as running, or returns false when one already is. Every
  /// action claims *before* its first `await`, so two taps can never both pass.
  bool _claim() {
    if (_busy) return false;
    _safeEmit(state.copyWith(status: VisitDetailStatus.acting));
    return true;
  }

  /// Runs [body] as [action] and reports the outcome.
  ///
  /// Only [body] decides success. The re-read afterwards is presentation: if
  /// it fails, the action still succeeded on the server, and reporting it as
  /// failed made users repeat it — a second attachment upload, say.
  Future<bool> _run(VisitAction action, Future<Object?> Function() body) async {
    if (!_claim()) return false;
    try {
      await body();
    } catch (e) {
      await _emitFailure(_asApiException(e));
      return false;
    }
    await _emitSuccess(VisitActionOutcome(action));
    return true;
  }

  /// Settles back to `ready` after a successful action, showing the freshest
  /// copy of the visit the server will give — or the one already on screen if
  /// the re-read fails. Never throws.
  Future<void> _emitSuccess(
    VisitActionOutcome outcome, {
    bool recheckMockFlag = false,
  }) async {
    final attachmentsFuture = _readAttachments();
    final (visit, _) = await _readVisit();
    final (attachments, attachmentsError) = await attachmentsFuture;
    // Start and End are the two actions that can *raise* the flag, and they
    // do it server-side inside the action, so the record is re-read for them.
    final mockFlagged =
        state.mockFlagged ||
        (recheckMockFlag && await repository.hasMockLocationFlag(visitId));
    _reconcileTrail(visit);
    _safeEmit(
      VisitDetailState(
        status: VisitDetailStatus.ready,
        visit: visit ?? state.visit,
        lastAction: outcome,
        attachments: attachments,
        attachmentsError: attachmentsError,
        // These emits build a fresh state rather than copyWith, so every one of
        // them has to carry the flag forward explicitly — otherwise approving a
        // visit would quietly clear a spoofing warning raised at check-in.
        mockFlagged: mockFlagged,
      ),
    );
  }

  /// Settles back to `ready` with [error] attached, after re-reading the visit
  /// so the header and action bar stay truthful even though the action failed.
  Future<void> _emitFailure(ApiException error) async {
    final (visit, _) = await _readVisit();
    _safeEmit(
      VisitDetailState(
        status: VisitDetailStatus.ready,
        visit: visit ?? state.visit,
        error: error,
        attachments: state.attachments,
        attachmentsError: state.attachmentsError,
        mockFlagged: state.mockFlagged,
      ),
    );
  }

  Future<bool> submit() =>
      _run(VisitAction.submit, () => repository.submit(visitId));

  Future<bool> approve() =>
      _run(VisitAction.approve, () => repository.approve(visitId));

  Future<bool> reject(String reason) =>
      _run(VisitAction.reject, () => repository.reject(visitId, reason));

  Future<bool> cancel() =>
      _run(VisitAction.cancel, () => repository.cancel(visitId));

  Future<bool> reschedule({
    DateTime? scheduledDatetime,
    String? purpose,
    String? location,
  }) => _run(
    VisitAction.reschedule,
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
  ///
  /// The trail is recorded only once the server has confirmed the visit is
  /// `in_progress`. A Start that could only be queued offline records
  /// nothing; recording begins when the queue has replayed it (see
  /// `VisitTrailTracker.onQueuedStartSynced`).
  Future<bool> start({
    required double latitude,
    required double longitude,
    String? location,
    bool isMocked = false,
  }) async {
    if (!_claim()) return false;
    return _runQueueable(
      VisitAction.start,
      _queuedPayload(
        VisitAction.start,
        latitude: latitude,
        longitude: longitude,
        location: location,
        isMocked: isMocked,
      ),
      () => repository.start(
        visitId,
        latitude: latitude,
        longitude: longitude,
        location: location,
        isMocked: isMocked,
      ),
      onSent: (transition) {
        if (transition.state != VisitState.inProgress) {
          appLog(
            '[VisitDetailCubit] start of $visitId answered '
            '${transition.state?.name}; trail not recorded',
          );
          return;
        }
        unawaited(
          _startTrail(
            startedAt: transition.at,
            seedLatitude: latitude,
            seedLongitude: longitude,
          ),
        );
      },
    );
  }

  /// See [start] on why the coordinates are required.
  ///
  /// Recording stops *before* the End goes out, and everything recorded up to
  /// then is pushed: the server stamps `end_datetime` on End, so a fix taken
  /// while the request is in flight would land after it. The End's own
  /// coordinates, acquired fresh by the caller, are the trail's final point.
  Future<bool> end({
    required String outcome,
    required double latitude,
    required double longitude,
    String? location,
    bool isMocked = false,
  }) async {
    // Claimed before the tracker is touched, so a second End tapped while the
    // first is still stopping the tracker is refused as busy instead of being
    // read as a failed End that restarts recording.
    if (!_claim()) return false;
    final tracker = _trail;
    // Only this visit's own recording is stopped; a tracker busy with another
    // visit keeps going and just gets flushed.
    final trackingThis =
        tracker != null &&
        (tracker.activeVisitId == null || tracker.activeVisitId == visitId);
    if (trackingThis) {
      await _guardTrail('stop before End', tracker.stop);
    } else if (tracker != null) {
      await _guardTrail(
        'flush before End',
        () => tracker.drain().then((_) => tracker.flushNow()),
      );
    }
    final ok = await _runQueueable(
      VisitAction.end,
      _queuedPayload(
        VisitAction.end,
        outcome: outcome,
        latitude: latitude,
        longitude: longitude,
        location: location,
        isMocked: isMocked,
      ),
      () => repository.end(
        visitId,
        outcome: outcome,
        latitude: latitude,
        longitude: longitude,
        location: location,
        isMocked: isMocked,
      ),
    );
    // Refused (no outcome, state moved on): if the server still has the visit
    // in progress, its route must keep recording. An End that only reached
    // the offline queue counts as success — recording stays stopped, and the
    // buffered tail uploads while the server still has the visit open.
    if (!ok && trackingThis && (state.visit?.isInProgress ?? false)) {
      unawaited(_startTrail(startedAt: state.visit?.startDatetime));
    }
    return ok;
  }

  /// Starts recording this visit's trail. Never throws — it runs unawaited,
  /// and a tracker failure must not surface as an unhandled async error.
  Future<void> _startTrail({
    DateTime? startedAt,
    double? seedLatitude,
    double? seedLongitude,
  }) =>
      _guardTrail(
        'start',
        () async => _trail?.start(
          visitId,
          startedAt: startedAt,
          seedLatitude: seedLatitude,
          seedLongitude: seedLongitude,
        ),
      );

  Future<void> _guardTrail(String what, Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      // The buffered tail stays on the device and flushes later; the visit
      // action itself must not be held back by the trail.
      appLog('[VisitDetailCubit] trail $what failed: $e');
    }
  }

  /// The offline-queue record for a Start / End. Keys are shared with the
  /// queue that replays it, and `type` keeps the values stored data already
  /// uses (`start` / `end`).
  static Map<String, dynamic> _queuedPayload(
    VisitAction action, {
    required double latitude,
    required double longitude,
    String? outcome,
    String? location,
    required bool isMocked,
  }) => {
    QueuedVisitActionFields.type: action.name,
    if (outcome != null) QueuedVisitActionFields.outcome: outcome,
    QueuedVisitActionFields.latitude: latitude,
    QueuedVisitActionFields.longitude: longitude,
    if (location != null) QueuedVisitActionFields.location: location,
    if (isMocked) QueuedVisitActionFields.isMocked: true,
  };

  /// A failure that means the request never reached a working server, so the
  /// action is safe to hold and replay. Anything else is a verdict on the
  /// action itself, and replaying it would only fail again later.
  static bool _isOffline(ApiException e) =>
      e.code == ApiErrorCode.network ||
      e.code == ApiErrorCode.timeout ||
      e.code == ApiErrorCode.serverUnavailable;

  /// Like [_run] but for the GPS-stamped Start / End actions, which the caller
  /// has already claimed: if the network is down we persist the action to the
  /// offline queue and report a soft success (a queued [VisitActionOutcome])
  /// instead of an error, so a field rep in a dead zone can keep working. The
  /// queue replays it automatically when connectivity is back.
  ///
  /// [onSent] runs with the server's answer as soon as it arrives — before the
  /// visit is re-read — and never for a queued action.
  ///
  /// Only a failure of [body] is queued. A re-read failing *after* the server
  /// accepted the action used to land here too, and queued a Start the server
  /// already had — replayed later, refused, and reported to the rep as lost.
  Future<bool> _runQueueable(
    VisitAction action,
    Map<String, dynamic> payload,
    Future<VisitTransition> Function() body, {
    void Function(VisitTransition transition)? onSent,
  }) async {
    assert(action.isQueueable, '$action cannot be held offline');
    final VisitTransition transition;
    try {
      transition = await body();
    } on ApiException catch (e) {
      if (_isOffline(e)) return _holdOffline(action, payload, e);
      await _emitFailure(e);
      return false;
    } catch (e) {
      await _emitFailure(ApiException.unexpected(e));
      return false;
    }
    onSent?.call(transition);
    await _emitSuccess(VisitActionOutcome(action), recheckMockFlag: true);
    return true;
  }

  /// Holds [payload] for replay and moves the screen on as if it had been
  /// accepted. Falls back to reporting [cause] when the action can't be held.
  Future<bool> _holdOffline(
    VisitAction action,
    Map<String, dynamic> payload,
    ApiException cause,
  ) async {
    final queue = _pending;
    if (queue == null) {
      await _emitFailure(cause);
      return false;
    }
    // The enqueue needs its own guard: a SharedPreferences write failure
    // (storage full, channel error) would otherwise escape, leaving status
    // stuck on `acting` — the full-screen busy overlay spinning forever, with
    // the action lost and nothing said about it.
    try {
      await queue.enqueue(visitId, payload);
    } catch (queueError) {
      await _emitFailure(ApiException.unexpected(queueError));
      return false;
    }
    // Advance the local state to match what was queued. Without this the
    // visit still reads `approved` after an offline Start, so the action bar
    // keeps offering Start and never offers End (`canEnd` requires
    // `inProgress`) — a rep who starts a visit in a dead zone could not finish
    // it until connectivity returned, which is the exact situation the queue
    // exists to cover.
    // On the server's clock, like the times the server will stamp: the bar's
    // running timer measures from this.
    final now = slMaybe<ServerClock>()?.now() ?? DateTime.now().toUtc();
    final optimistic = switch (action) {
      VisitAction.start => state.visit?.copyWith(
        state: VisitState.inProgress,
        startDatetime: now,
      ),
      VisitAction.end => state.visit?.copyWith(
        state: VisitState.done,
        endDatetime: now,
        outcome: payload[QueuedVisitActionFields.outcome]?.toString(),
      ),
      _ => state.visit,
    };
    _safeEmit(
      state.copyWith(
        status: VisitDetailStatus.ready,
        visit: optimistic,
        lastAction: VisitActionOutcome(action, queued: true),
        // Queued offline: the note has not been posted yet, but the verdict is
        // already known locally, so warn now rather than after the sync.
        mockFlagged:
            state.mockFlagged ||
            payload[QueuedVisitActionFields.isMocked] == true,
      ),
    );
    return true;
  }

  Future<bool> addParticipants(List<int> employeeIds) => _run(
    VisitAction.addParticipants,
    () => repository.addParticipants(visitId, employeeIds),
  );

  Future<bool> approveParticipant(int participantId) => _run(
    VisitAction.participantApprove,
    () => repository.approveParticipant(participantId),
  );

  Future<bool> rejectParticipant(int participantId, String reason) => _run(
    VisitAction.participantReject,
    () => repository.rejectParticipant(participantId, reason),
  );

  Future<bool> uploadAttachment({
    required String filename,
    required String dataB64,
  }) => _run(
    VisitAction.attachment,
    () => repository.uploadAttachment(
      visitId,
      filename: filename,
      dataB64: dataB64,
    ),
  );
}
