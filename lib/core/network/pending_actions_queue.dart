import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/visits/data/models/visit.dart';
import '../../features/visits/data/visits_repository.dart';
import '../../features/visits/domain/visit_action.dart';
import '../api/api_exceptions.dart';
import '../location/tracker_plumbing.dart';
import '../constants.dart';
import '../utils/app_log.dart';
import 'connectivity_status.dart';

/// One queued visit workflow action (currently **Start** / **End**) that could
/// not be sent because the network was down.
///
/// The payload is kept as the detail screen wrote it (keys in
/// [QueuedVisitActionFields]); the rest is bookkeeping the queue needs to
/// decide when to retry and when to give up.
class PendingAction {
  final int visitId;
  final Map<String, dynamic> payload;
  final DateTime queuedAt;

  /// Who queued it: the server and Odoo user it must be replayed as (see
  /// [PendingActionsQueue.owner]). Null for entries written before the queue
  /// was scoped; the first signed-in user adopts those.
  final String? owner;

  /// Failed replays that counted towards [AppConstants.pendingActionMaxAttempts].
  /// Plain connectivity failures don't count — a rep can be offline for hours.
  final int attempts;

  const PendingAction({
    required this.visitId,
    required this.payload,
    required this.queuedAt,
    this.owner,
    this.attempts = 0,
  });

  /// The action this entry replays, or null for an unknown / legacy type.
  VisitAction? get action {
    final type = payload[QueuedVisitActionFields.type]?.toString();
    for (final a in VisitAction.values) {
      if (a.name == type && a.isQueueable) return a;
    }
    return null;
  }

  /// Identity of this entry across re-reads of the store. `queuedAt` is part of
  /// it so a re-queued action (same visit and type, newer intent) is a
  /// different entry from the one a running flush is replaying.
  bool sameEntryAs(PendingAction other) =>
      other.visitId == visitId &&
      other.payload[QueuedVisitActionFields.type] ==
          payload[QueuedVisitActionFields.type] &&
      other.queuedAt == queuedAt;

  PendingAction copyWith({String? owner, int? attempts}) => PendingAction(
        visitId: visitId,
        payload: payload,
        queuedAt: queuedAt,
        owner: owner ?? this.owner,
        attempts: attempts ?? this.attempts,
      );

  Map<String, dynamic> toJson() => {
        'visitId': visitId,
        'payload': payload,
        'queuedAt': queuedAt.toIso8601String(),
        if (owner != null) 'owner': owner,
        if (attempts > 0) 'attempts': attempts,
      };

  factory PendingAction.fromJson(Map<String, dynamic> j) => PendingAction(
        visitId: (j['visitId'] as num).toInt(),
        payload: Map<String, dynamic>.from(j['payload'] as Map),
        queuedAt: DateTime.parse(j['queuedAt'].toString()),
        owner: j['owner'] is String ? j['owner'] as String : null,
        attempts: j['attempts'] is num ? (j['attempts'] as num).toInt() : 0,
      );
}

/// A queued offline action the server refused for good, so the UI can explain
/// the loss instead of letting the work disappear.
class DroppedAction {
  final int visitId;

  /// What was lost — Start or End. Null only for an unreadable legacy entry.
  final VisitAction? action;

  /// Why it was refused. Localize with `ApiExceptionL10n.localize` before
  /// showing it — never render this raw.
  final ApiException error;

  const DroppedAction({
    required this.visitId,
    required this.error,
    this.action,
  });
}

/// A queued action that reached the server (or was found already applied).
typedef SyncedAction = ({int visitId, VisitAction? action});

/// What one [PendingActionsQueue.flush] did.
class FlushResult {
  /// Actions the server accepted (or had already applied).
  final int synced;

  /// Actions abandoned; each was also announced on
  /// [PendingActionsQueue.onDropped].
  final int dropped;

  /// Actions still waiting for the signed-in user after the flush.
  final int remaining;

  const FlushResult({
    this.synced = 0,
    this.dropped = 0,
    this.remaining = 0,
  });

  static const empty = FlushResult();
}

/// Offline queue for visit Start / End. Persists to SharedPreferences so the
/// work survives a restart, and replays it when connectivity returns.
///
/// Rules worth knowing:
///
/// - **One action per visit and type.** A repeated Start replaces the queued
///   Start; an End queues beside it, and both replay in the order performed.
/// - **Dropped only on a verdict about the data** — validation, conflict, not
///   found, permission denied. Everything else (offline, an outage, a proxy
///   page, an expired session) is retried: those say nothing about the action,
///   and dropping on them lost GPS-stamped work for good.
/// - **A refusal is checked before it is believed.** A Start whose first
///   attempt timed out may well have reached the server; its replay is then
///   refused ("only an approved visit can be started") although the work is
///   saved. The visit is re-read, and an action whose target state is already
///   reached counts as synced.
/// - **Scoped to one server and user.** Entries carry their [owner]; another
///   account signing in on the same phone neither sees nor replays them.
class PendingActionsQueue {
  static const _prefsKey = StorageKeys.pendingActions;
  static const _lastSyncKey = StorageKeys.pendingActionsLastSync;

  /// The codes that are a final answer about the action itself.
  static const _verdicts = {
    ApiErrorCode.validation,
    ApiErrorCode.conflict,
    ApiErrorCode.notFound,
    ApiErrorCode.permissionDenied,
  };

  final SharedPreferences prefs;
  final VisitsRepository repository;
  final ConnectivityStatus connectivity;

  /// Resolves who is signed in, as `server|uid`, or null when nobody is. Null
  /// resolver (tests, single-user tools): every entry belongs to everyone.
  final Future<String?> Function()? ownerResolver;

  final DateTime Function() _now;

  Timer? _ticker;
  Future<FlushResult>? _flushInFlight;
  String? _owner;

  /// Number of actions waiting for the signed-in user. Listeners redraw a
  /// "pending sync" badge from it.
  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);

  /// When a queued action last replayed to the server successfully, or `null`
  /// if nothing has ever been synced from this device.
  ///
  /// Persisted so it survives a restart. The Settings "Last sync" row renders
  /// this — it must be a real observation, never a stand-in string, or a field
  /// employee with unsynced check-ins is told their work is already uploaded.
  final ValueNotifier<DateTime?> lastSyncedAt = ValueNotifier<DateTime?>(null);

  final StreamController<SyncedAction> _synced =
      StreamController<SyncedAction>.broadcast();

  /// Fires when a queued action reaches the server, so list pages can refresh
  /// and — for a Start — the visit's trail recording can begin now that the
  /// server confirms it.
  Stream<SyncedAction> get onSynced => _synced.stream;

  late final StreamController<DroppedAction> _dropped =
      StreamController<DroppedAction>.broadcast(onListen: _deliverBacklog);

  /// Drops announced while nobody listened (the home screen wasn't mounted).
  /// Held until the next listener arrives: the user was told "saved, will
  /// sync", so the loss must reach them eventually.
  final List<DroppedAction> _undelivered = [];

  /// Fires when a queued action is abandoned because the server refused it.
  ///
  /// Whoever listens must tell the user: they believe that GPS-stamped work is
  /// recorded.
  Stream<DroppedAction> get onDropped => _dropped.stream;

  PendingActionsQueue({
    required this.prefs,
    required this.repository,
    required this.connectivity,
    this.ownerResolver,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _publishCount();
    lastSyncedAt.value = _readLastSync();
    connectivity.addListener(_onConnectivityChanged);
  }

  /// The `server|uid` the visible entries belong to (null: signed out, or
  /// unscoped when there is no resolver).
  String? get owner => _owner;

  void _onConnectivityChanged() {
    if (connectivity.isOnline) unawaited(flush());
  }

  /// Periodically retries the queue. The connectivity listener handles the
  /// common case (network came back); the heartbeat covers "marked online but
  /// the request still failed" without the user retrying by hand.
  void startBackgroundFlush() {
    _ticker?.cancel();
    _ticker = Timer.periodic(
      AppConstants.pendingActionFlushInterval,
      (_) => unawaited(flush()),
    );
  }

  void stopBackgroundFlush() {
    _ticker?.cancel();
    _ticker = null;
  }

  /// Re-reads who is signed in and re-scopes the visible queue. Call when the
  /// session changes (sign-in, sign-out, server switch); [flush] and
  /// [enqueue] also call it.
  Future<void> refreshOwner() async {
    final resolver = ownerResolver;
    if (resolver == null) return;
    try {
      _owner = await resolver();
    } catch (e) {
      appLog('[PendingActionsQueue] could not resolve the signed-in user: $e');
      _owner = null;
    }
    final owner = _owner;
    if (owner != null) {
      // Entries from before the queue was scoped belong to whoever signs in
      // first — the only user the old app could have queued them for.
      final all = _readAll();
      if (all.any((a) => a.owner == null)) {
        await _writeAll([
          for (final a in all) a.owner == null ? a.copyWith(owner: owner) : a,
        ]);
      }
    }
    _publishCount();
  }

  /// Saves [payload] for [visitId], replacing a queued action of the **same
  /// type** for that visit.
  ///
  /// Keyed on `(visitId, type)` rather than `visitId` alone: a visit-only key
  /// made an offline End overwrite the offline Start of the same visit, the
  /// server then refused the End for a visit it still had as approved, and the
  /// rep's whole dead-zone visit was lost.
  Future<void> enqueue(int visitId, Map<String, dynamic> payload) async {
    await refreshOwner();
    final type = payload[QueuedVisitActionFields.type]?.toString();
    final owner = _owner;
    // Read and write with no await in between: SharedPreferences updates its
    // cache synchronously, so this cannot interleave with a running flush.
    final all = _readAll()
      ..removeWhere((a) =>
          a.visitId == visitId &&
          _isVisible(a) &&
          a.payload[QueuedVisitActionFields.type]?.toString() == type)
      ..add(PendingAction(
        visitId: visitId,
        payload: payload,
        queuedAt: _now(),
        owner: owner,
      ));
    await _writeAll(all);
  }

  /// Drops the signed-in user's queued actions for [visitId] (the work went
  /// through another way).
  Future<void> clear(int visitId) async {
    final all = _readAll()
      ..removeWhere((a) => a.visitId == visitId && _isVisible(a));
    await _writeAll(all);
  }

  /// The signed-in user's queued actions, oldest first.
  List<PendingAction> get pending => _readAll().where(_isVisible).toList();

  /// Sends the signed-in user's queued actions, in order, stopping at the
  /// first one that can't go through yet.
  ///
  /// A call made while a flush is running waits for that flush and returns its
  /// result, instead of reporting a stale count.
  Future<FlushResult> flush() {
    final running = _flushInFlight;
    if (running != null) return running;
    final next = _runFlush();
    _flushInFlight = next;
    return next.whenComplete(() => _flushInFlight = null);
  }

  Future<FlushResult> _runFlush() async {
    await refreshOwner();
    if (ownerResolver != null && _owner == null) return FlushResult.empty;

    final snapshot = pending;
    if (snapshot.isEmpty) return FlushResult.empty;

    final done = <PendingAction>[];
    final retried = <PendingAction>[];
    var synced = 0;
    var dropped = 0;

    for (final a in snapshot) {
      final outcome = await _attempt(a);
      switch (outcome) {
        case _Synced():
          synced++;
          done.add(a);
          _synced.add((visitId: a.visitId, action: a.action));
        case _Dropped(:final error):
          dropped++;
          done.add(a);
          appLog('[PendingActionsQueue] dropping ${a.action?.name} for visit '
              '${a.visitId}: ${error.code} ${error.details ?? ''}');
          _announce(DroppedAction(
            visitId: a.visitId,
            action: a.action,
            error: error,
          ));
        case _Retry(:final countsAsAttempt):
          if (countsAsAttempt) {
            retried.add(a.copyWith(attempts: a.attempts + 1));
          }
      }
      // Later actions depend on earlier ones (an End needs its Start), so the
      // first one that must wait holds back the rest.
      if (outcome is _Retry) break;
    }

    // Re-read rather than write the snapshot back: an action queued or cleared
    // while the replays above were awaiting must survive this write.
    final current = _readAll()
      ..removeWhere((a) => done.any(a.sameEntryAs));
    for (var i = 0; i < current.length; i++) {
      for (final r in retried) {
        if (current[i].sameEntryAs(r)) current[i] = r;
      }
    }
    await _writeAll(current);
    // Only stamp a sync that was observed. A flush that replayed nothing must
    // leave the previous timestamp alone.
    if (synced > 0) await _writeLastSync(_now());
    return FlushResult(
      synced: synced,
      dropped: dropped,
      remaining: pendingCount.value,
    );
  }

  /// Replays one action and decides what its failure means.
  Future<_Outcome> _attempt(PendingAction a) async {
    final action = a.action;
    if (action == null) {
      // Unknown / legacy payload. It can never be replayed, and returning
      // normally would count it as synced and delete it without a word.
      return _Dropped(ApiException.unexpected(StateError(
        'unreplayable queued action '
        '"${a.payload[QueuedVisitActionFields.type]}" for visit ${a.visitId}',
      )));
    }
    try {
      await _replay(action, a);
      return const _Synced();
    } on ApiException catch (e) {
      if (e.isSessionProblem) {
        // The user signs in again and the action goes then; not its fault.
        return const _Retry(countsAsAttempt: false);
      }
      if (_verdicts.contains(e.code)) {
        if (await _alreadyApplied(action, a.visitId) case final applied?) {
          return applied ? const _Synced() : _Dropped(e);
        }
        // The server refused, but the visit couldn't be re-read to check
        // whether an earlier attempt landed. Ask again next time.
        return _retryOrDrop(a, e, countsAsAttempt: true);
      }
      final connectivityOnly =
          e.code == ApiErrorCode.network || e.code == ApiErrorCode.timeout;
      return _retryOrDrop(a, e, countsAsAttempt: !connectivityOnly);
    } catch (e) {
      return _retryOrDrop(a, ApiException.unexpected(e),
          countsAsAttempt: true);
    }
  }

  /// Keeps [a] for another try, unless it has used up its attempts or grown
  /// too old to be worth replaying.
  _Outcome _retryOrDrop(
    PendingAction a,
    ApiException error, {
    required bool countsAsAttempt,
  }) {
    final exhausted = countsAsAttempt &&
        a.attempts + 1 >= AppConstants.pendingActionMaxAttempts;
    final expired =
        _now().difference(a.queuedAt) > AppConstants.pendingActionMaxAge;
    if (exhausted || expired) return _Dropped(error);
    return _Retry(countsAsAttempt: countsAsAttempt);
  }

  /// Whether the server already shows [action]'s effect on the visit: true /
  /// false, or null when the visit could not be read.
  Future<bool?> _alreadyApplied(VisitAction action, int visitId) async {
    final Visit? visit;
    try {
      visit = await repository.getVisit(visitId);
    } on ApiException catch (e) {
      // A transient failure leaves the question open; any other answer means
      // the visit can't be read, so it can't have moved on either.
      return e.isTransient ? null : false;
    } catch (_) {
      return false;
    }
    if (visit == null) return false;
    return switch (action) {
      VisitAction.start => visit.state == VisitState.inProgress ||
          visit.state == VisitState.done,
      VisitAction.end => visit.state == VisitState.done,
      _ => false,
    };
  }

  /// Replays a single queued action against the live workflow API.
  Future<void> _replay(VisitAction action, PendingAction a) async {
    final p = a.payload;
    final lat = (p[QueuedVisitActionFields.latitude] as num?)?.toDouble();
    final lng = (p[QueuedVisitActionFields.longitude] as num?)?.toDouble();
    final location = p[QueuedVisitActionFields.location]?.toString();
    // Carried through the queue so an offline start is exactly as accountable
    // as a live one. Without this, "go into airplane mode first" would strip
    // the spoofing verdict off a fake check-in.
    final isMocked = p[QueuedVisitActionFields.isMocked] == true;
    switch (action) {
      case VisitAction.start:
        await repository.start(
          a.visitId,
          latitude: lat,
          longitude: lng,
          location: location,
          isMocked: isMocked,
        );
      case VisitAction.end:
        await repository.end(
          a.visitId,
          outcome: p[QueuedVisitActionFields.outcome]?.toString() ?? '',
          latitude: lat,
          longitude: lng,
          location: location,
          isMocked: isMocked,
        );
      default:
        throw StateError('${action.name} is not a queueable action');
    }
  }

  void _announce(DroppedAction drop) {
    if (_dropped.hasListener) {
      _dropped.add(drop);
    } else {
      _undelivered.add(drop);
    }
  }

  void _deliverBacklog() {
    if (_undelivered.isEmpty) return;
    final backlog = List.of(_undelivered);
    _undelivered.clear();
    // Deferred: the subscription that triggered this is not listening yet.
    scheduleMicrotask(() => backlog.forEach(_announce));
  }

  /// Whether [a] belongs to the signed-in user. Without a resolver the queue is
  /// unscoped; signed out, nothing is visible.
  bool _isVisible(PendingAction a) {
    if (ownerResolver == null) return true;
    final owner = _owner;
    return owner != null && (a.owner == null || a.owner == owner);
  }

  void _publishCount() {
    pendingCount.value = pending.length;
  }

  List<PendingAction> _readAll() {
    // Entry by entry: one malformed record (a null visitId from a partial
    // write) must not discard every other queued check-in.
    final actions = <PendingAction>[];
    var skipped = 0;
    for (final m in decodeStoredJsonList(() => prefs.getString(_prefsKey))) {
      try {
        actions.add(PendingAction.fromJson(m));
      } catch (e) {
        skipped++;
        appLog('[PendingActionsQueue] skipping unreadable queue entry: $e');
      }
    }
    if (skipped > 0) {
      appLog('[PendingActionsQueue] $skipped unreadable entry/entries '
          'skipped; ${actions.length} kept');
    }
    return actions;
  }

  Future<void> _writeAll(List<PendingAction> actions) async {
    final write = prefs.setString(
      _prefsKey,
      jsonEncode(actions.map((a) => a.toJson()).toList()),
    );
    _publishCount();
    await write;
  }

  DateTime? _readLastSync() {
    try {
      final raw = prefs.getString(_lastSyncKey);
      return raw == null || raw.isEmpty ? null : DateTime.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeLastSync(DateTime when) async {
    lastSyncedAt.value = when;
    await prefs.setString(_lastSyncKey, when.toIso8601String());
  }

  void dispose() {
    _ticker?.cancel();
    connectivity.removeListener(_onConnectivityChanged);
    _synced.close();
    _dropped.close();
    pendingCount.dispose();
    lastSyncedAt.dispose();
  }
}

/// What one replay attempt came to.
sealed class _Outcome {
  const _Outcome();
}

class _Synced extends _Outcome {
  const _Synced();
}

class _Dropped extends _Outcome {
  final ApiException error;
  const _Dropped(this.error);
}

class _Retry extends _Outcome {
  /// Whether this failure uses up one of the action's attempts.
  final bool countsAsAttempt;
  const _Retry({required this.countsAsAttempt});
}
