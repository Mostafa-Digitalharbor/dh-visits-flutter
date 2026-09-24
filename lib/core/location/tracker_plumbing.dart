// tracker_plumbing.dart — the machinery both GPS trackers need and neither
// owns.
//
// [VisitTrailTracker] and [WorkdayTracker] record different things (one visit
// vs. a whole work day) against different server contracts, and deliberately
// stay separate classes. But the plumbing underneath was written twice, line
// for line: resolve the install's device id once and cache it, express a
// device timestamp on the server's clock, ask whether the app is in the
// foreground, and run a background step without ever letting it throw.
//
// Two copies of a helper is two places to fix a bug in it — and the trackers
// had already drifted once, where the same predicate existed in three
// versions and the narrowest silently dropped a work day's GPS path (see
// [ApiException.isRetryable]). This mixin is where that class of drift stops.
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../network/server_clock.dart';
import '../utils/app_log.dart';

/// Shared, stateless-by-itself helpers for the two GPS trackers.
///
/// Implementers supply [logTag], [serverClock] and [deviceId]; the `final`
/// fields the trackers already declare satisfy the last two.
mixin TrackerPlumbing {
  /// Prefix every diagnostic from this tracker carries, e.g.
  /// `[VisitTrailTracker]`. Written once here instead of at each call site.
  String get logTag;

  /// Re-expresses device-clock instants on the server's clock so a timestamp
  /// is comparable with the ones the server stamps. Null (in tests) leaves
  /// device time unchanged.
  ServerClock? get serverClock;

  /// Stable per-install id sent as each point's `device_id` — the same one the
  /// FCM registration uses. Null where the app has no identity source.
  Future<String?> Function()? get deviceId;

  /// The resolved [deviceId], once [resolveDeviceId] has run. Null until then,
  /// and null for good if resolving it failed — a point without a device id is
  /// still worth sending.
  String? deviceIdValue;

  /// Resolves [deviceId] once and caches it. Never throws: a missing device id
  /// must not stop a fix from being recorded.
  Future<void> resolveDeviceId() async {
    if (deviceIdValue != null || deviceId == null) return;
    try {
      deviceIdValue = await deviceId!();
    } catch (e) {
      appLog('$logTag device id unavailable: $e');
    }
  }

  /// Whether the app is in the foreground. `null` lifecycle state means the
  /// framework has not reported one yet, which on a cold start is the
  /// foreground.
  bool get isForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  /// A device-clock instant expressed on the server's clock.
  DateTime serverTimeOf(DateTime deviceTime) =>
      serverClock?.toServer(deviceTime) ?? deviceTime.toUtc();

  /// A server-clock instant expressed on the device's clock.
  DateTime? deviceTimeOf(DateTime? serverTime) {
    if (serverTime == null) return null;
    return serverClock?.toDevice(serverTime) ?? serverTime.toUtc();
  }

  /// Now, on the server's clock.
  DateTime serverNow() => serverClock?.now() ?? DateTime.now().toUtc();

  /// Runs a background step and swallows anything it throws, naming [what] in
  /// the log.
  ///
  /// Every caller is a timer tick, a lifecycle callback or a connectivity
  /// listener — places with no one to catch for them, where an escaping
  /// exception becomes an unhandled async error and takes the tracker's
  /// periodic work down with it.
  Future<void> guard(String what, Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      appLog('$logTag $what failed: $e');
    }
  }
}

/// The JSON list persisted under a `SharedPreferences` key, or `[]` when there
/// is nothing readable there.
///
/// Both trackers and [PendingActionsQueue] persist their backlog as a JSON
/// array in one preferences string, and all three had the same two-step
/// salvage written out by hand: a wrong *type* under the key throws on read,
/// and a truncated write leaves text that is not JSON. Either way the right
/// answer is an empty backlog rather than an exception on startup — losing a
/// buffer is bad, failing to launch is worse.
///
/// Decoding each *entry* stays with the caller: one unreadable record must not
/// discard the rest, and each backlog knows its own row shape.
List<Map<String, dynamic>> decodeStoredJsonList(String? Function() read) {
  final String? raw;
  try {
    raw = read();
  } catch (_) {
    // A value of another type under this key: nothing readable to salvage.
    return const [];
  }
  if (raw == null || raw.isEmpty) return const [];
  final List<dynamic> list;
  try {
    list = jsonDecode(raw) as List;
  } catch (_) {
    // The whole blob is unreadable — start fresh rather than crash on read.
    return const [];
  }
  return [
    for (final m in list.whereType<Map>()) Map<String, dynamic>.from(m),
  ];
}
