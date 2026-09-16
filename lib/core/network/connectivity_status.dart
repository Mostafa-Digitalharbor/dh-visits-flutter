import 'dart:async';

import 'package:flutter/foundation.dart';

/// Lightweight online/offline tracker. We don't subscribe to OS-level
/// connectivity events (which would need `connectivity_plus`) — instead
/// the API layer flips this flag based on whether requests reach the server:
/// a connection failure marks offline, the next answer marks online again.
///
/// That leaves one gap: an idle app that went offline makes no request, so it
/// would never notice the network coming back and the offline banner would
/// stay up. While offline, [probe] is therefore tried every [probeInterval];
/// any answer it gets flips the flag back through the API layer.
///
/// Held as a `ValueNotifier` so widgets can `ValueListenableBuilder`
/// without going through a Bloc — there's only ever one global piece
/// of state.
class ConnectivityStatus extends ValueNotifier<bool> {
  ConnectivityStatus({this.probe, this.probeInterval = defaultProbeInterval})
      : super(true) {
    addListener(_syncProbing);
  }

  /// How often an offline app checks whether the server is back.
  static const Duration defaultProbeInterval = Duration(seconds: 20);

  /// A cheap request to the server. Its outcome is ignored here: reaching the
  /// server is what marks the app online (see `ApiClient`).
  final Future<void> Function()? probe;
  final Duration probeInterval;

  Timer? _probeTimer;

  /// True when the last network call we observed succeeded (i.e. we
  /// believe we have internet right now).
  bool get isOnline => value;

  void markOnline() {
    if (!value) value = true;
  }

  void markOffline() {
    if (value) value = false;
  }

  void _syncProbing() {
    final run = probe;
    if (value || run == null) {
      _probeTimer?.cancel();
      _probeTimer = null;
      return;
    }
    _probeTimer ??= Timer.periodic(probeInterval, (_) async {
      try {
        await run();
      } catch (_) {
        // Still offline, or the server answered with an error — either way
        // the API layer has already updated the flag.
      }
    });
  }

  @override
  void dispose() {
    _probeTimer?.cancel();
    removeListener(_syncProbing);
    super.dispose();
  }
}
