import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_exceptions.dart';
import '../../features/visits/data/visits_repository.dart';
import 'connectivity_status.dart';

/// One queued visit workflow action (currently **Start** / **End**) that we
/// couldn't send to the server because the network was down. We keep the
/// payload as-is plus a few diagnostic fields so the UI can show the user when
/// their work was captured locally.
///
/// Payload shape:
/// - `type`: `'start'` | `'end'`
/// - `latitude` / `longitude`: the GPS fix captured offline (nullable)
/// - `outcome`: the visit outcome text (only for `'end'`)
class PendingAction {
  final int visitId;
  final Map<String, dynamic> payload;
  final DateTime queuedAt;

  const PendingAction({
    required this.visitId,
    required this.payload,
    required this.queuedAt,
  });

  Map<String, dynamic> toJson() => {
        'visitId': visitId,
        'payload': payload,
        'queuedAt': queuedAt.toIso8601String(),
      };

  factory PendingAction.fromJson(Map<String, dynamic> j) => PendingAction(
        visitId: (j['visitId'] as num).toInt(),
        payload: Map<String, dynamic>.from(j['payload'] as Map),
        queuedAt: DateTime.parse(j['queuedAt'].toString()),
      );
}

/// Minimal offline queue. Persists pending writes (the only ones we
/// care about today are check-in / check-out updates) to
/// SharedPreferences so they survive an app restart, and retries them
/// in the background when connectivity recovers.
///
/// Design decisions worth knowing:
///
/// - **One action per visit max.** If the user retries a check-in
///   that's still queued, we *replace* the existing action rather than
///   queuing a duplicate. Avoids the "I tapped twice and now my visit
///   has two check-ins" foot-gun.
/// - **Network errors only.** Only `network` / `timeout` failures
///   land here; validation / permission errors propagate to the
///   caller normally, since those won't fix themselves by retrying.
/// - **No conflict resolution.** If the server-side state changed
///   while we were offline (e.g. admin already marked the visit
///   done), our queued write may fail with a 4xx. We drop it from
///   the queue and surface the error rather than try to merge.
/// A queued offline action the server refused, so the UI can explain the loss
/// instead of letting the work disappear.
class DroppedAction {
  final int visitId;

  /// Why it was refused. Localize with `ApiExceptionL10n.localize` before
  /// showing it — never render this raw.
  final ApiException error;

  const DroppedAction({required this.visitId, required this.error});
}

class PendingActionsQueue {
  static const _prefsKey = 'pending_visit_actions_v1';

  final SharedPreferences prefs;
  final VisitsRepository repository;
  final ConnectivityStatus connectivity;

  Timer? _ticker;
  bool _flushing = false;

  /// Broadcast: number of pending actions changed. Listeners can
  /// `setState` to redraw a "pending sync" badge.
  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);

  /// Fires when a queued action successfully syncs to the server, so
  /// the list pages can refresh their data.
  final StreamController<int> _synced = StreamController<int>.broadcast();
  Stream<int> get onSynced => _synced.stream;

  /// Fires when a queued action is abandoned because the server rejected it.
  ///
  /// This matters: the user was told "saved, will sync" when they queued an
  /// offline check-in. If the replay is then refused — the visit moved on, a
  /// permission changed — dropping it silently loses GPS-stamped field work
  /// they believe is recorded. Whoever listens must tell them.
  final StreamController<DroppedAction> _dropped =
      StreamController<DroppedAction>.broadcast();
  Stream<DroppedAction> get onDropped => _dropped.stream;

  PendingActionsQueue({
    required this.prefs,
    required this.repository,
    required this.connectivity,
  }) {
    pendingCount.value = _readAll().length;
    // Retry queued work whenever connectivity recovers. Cheap — only
    // makes the network round-trip if the queue is non-empty.
    connectivity.addListener(() {
      if (connectivity.isOnline) {
        flush();
      }
    });
  }

  /// Start a background timer that periodically tries to drain the
  /// queue. The connectivity listener already handles the common case
  /// (network came back), but a 60s heartbeat catches edge cases like
  /// "we marked online but the request still failed" without forcing
  /// the user to manually retry.
  void startBackgroundFlush() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 60), (_) => flush());
  }

  void stopBackgroundFlush() {
    _ticker?.cancel();
    _ticker = null;
  }

  /// Save `payload` against `visitId`. If an action for the same
  /// visit already exists we replace it — the latest user intent
  /// wins.
  Future<void> enqueue(int visitId, Map<String, dynamic> payload) async {
    final all = _readAll();
    all.removeWhere((a) => a.visitId == visitId);
    all.add(PendingAction(
      visitId: visitId,
      payload: payload,
      queuedAt: DateTime.now(),
    ));
    await _writeAll(all);
  }

  /// Drop the queued action for a specific visit (called by callers
  /// who succeeded going around the queue, e.g. the user managed to
  /// finish the visit online before the auto-retry fired).
  Future<void> clear(int visitId) async {
    final all = _readAll();
    all.removeWhere((a) => a.visitId == visitId);
    await _writeAll(all);
  }

  List<PendingAction> get pending => _readAll();

  /// Try to send every queued action to the server. Stops early if
  /// the connection drops mid-flush — leftovers stay in the queue for
  /// the next attempt.
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final actions = _readAll();
      if (actions.isEmpty) return;
      final survivors = <PendingAction>[];
      for (var i = 0; i < actions.length; i++) {
        final a = actions[i];
        try {
          await _replay(a);
          _synced.add(a.visitId);
        } on ApiException catch (e) {
          if (e.code == ApiErrorCode.network ||
              e.code == ApiErrorCode.timeout) {
            // Still offline — keep this and everything after it, in order.
            survivors.addAll(actions.skip(i));
            break;
          }
          // 4xx / server errors (e.g. the visit's state moved on server-side
          // while we were offline) → drop the action, but announce it: the
          // user was promised this work was saved.
          debugPrint(
              '[PendingActionsQueue] dropping visit ${a.visitId}: '
              '${e.code} ${e.serverMessage}');
          _dropped.add(DroppedAction(visitId: a.visitId, error: e));
        } catch (e) {
          debugPrint(
              '[PendingActionsQueue] dropping visit ${a.visitId}: $e');
          _dropped.add(DroppedAction(
            visitId: a.visitId,
            error: ApiException.unexpected(e),
          ));
        }
      }
      await _writeAll(survivors);
    } finally {
      _flushing = false;
    }
  }

  /// Replays a single queued action against the live workflow API. Throws the
  /// repository's [ApiException] on failure so [flush] can decide whether to
  /// keep (offline) or drop (server rejected) the action.
  Future<void> _replay(PendingAction a) async {
    final type = a.payload['type']?.toString();
    final lat = (a.payload['latitude'] as num?)?.toDouble();
    final lng = (a.payload['longitude'] as num?)?.toDouble();
    final location = a.payload['location']?.toString();
    // Carried through the queue so an offline start is exactly as accountable
    // as a live one. Without this, "go into airplane mode first" would be a
    // way to strip the spoofing verdict off a fake check-in.
    final isMocked = a.payload['is_mocked'] == true;
    switch (type) {
      case 'start':
        await repository.start(a.visitId,
            latitude: lat,
            longitude: lng,
            location: location,
            isMocked: isMocked);
      case 'end':
        await repository.end(
          a.visitId,
          outcome: a.payload['outcome']?.toString() ?? '',
          latitude: lat,
          longitude: lng,
          location: location,
          isMocked: isMocked,
        );
      default:
        // Unknown / legacy payload — nothing we can replay; let it drain.
        debugPrint(
            '[PendingActionsQueue] discarding unknown action "$type" for '
            'visit ${a.visitId}');
    }
  }

  List<PendingAction> _readAll() {
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((m) => PendingAction.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      // Corrupt blob (different schema?) — drop and start fresh
      // rather than crash on read.
      return [];
    }
  }

  Future<void> _writeAll(List<PendingAction> actions) async {
    final raw = jsonEncode(actions.map((a) => a.toJson()).toList());
    await prefs.setString(_prefsKey, raw);
    pendingCount.value = actions.length;
  }

  void dispose() {
    _ticker?.cancel();
    _synced.close();
    _dropped.close();
    pendingCount.dispose();
  }
}
