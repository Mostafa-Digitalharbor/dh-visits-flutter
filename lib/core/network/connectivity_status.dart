import 'package:flutter/foundation.dart';

/// Lightweight online/offline tracker. We don't subscribe to OS-level
/// connectivity events (which would need `connectivity_plus`) — instead
/// the API layer flips this boolean based on whether requests succeed.
/// That's good enough for the offline-aware UI: as soon as one call
/// fails with a `network` error we mark offline, and the next
/// successful call marks online again.
///
/// Held as a `ValueNotifier` so widgets can `ValueListenableBuilder`
/// without going through a Bloc — there's only ever one global piece
/// of state.
class ConnectivityStatus extends ValueNotifier<bool> {
  ConnectivityStatus() : super(true);

  /// True when the last network call we observed succeeded (i.e. we
  /// believe we have internet right now).
  bool get isOnline => value;

  void markOnline() {
    if (!value) value = true;
  }

  void markOffline() {
    if (value) value = false;
  }
}
