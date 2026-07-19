// location_outcome.dart — the result of asking for the user's position.
//
// Exists because the previous helper returned `(double, double)?` and folded
// four very different outcomes into a single `null`: permission denied, GPS
// unavailable/timed out, the user cancelling the mock-location warning, and
// "no position". Callers then read `null` as "no coordinates, carry on" and
// started the visit anyway — so denying permission, or *cancelling the
// anti-spoofing prompt*, produced a visit with no GPS evidence at all. That
// made cancelling the strictly better move for anyone spoofing.
//
// A sealed type forces each case to be answered at the call site, and the
// switch is exhaustive at compile time.
import 'package:geolocator/geolocator.dart';

sealed class LocationOutcome {
  const LocationOutcome();
}

/// A usable position. [isMocked] is the OS's own mock-provider flag, kept on
/// the result so it can be recorded with the visit rather than only logged.
class LocationOk extends LocationOutcome {
  final double latitude;
  final double longitude;
  final bool isMocked;

  const LocationOk({
    required this.latitude,
    required this.longitude,
    this.isMocked = false,
  });

  factory LocationOk.from(Position p) => LocationOk(
        latitude: p.latitude,
        longitude: p.longitude,
        isMocked: p.isMocked,
      );
}

/// Location permission is denied, or the OS location service is switched off.
/// Actionable by the user, so it gets its own message.
class LocationPermissionDenied extends LocationOutcome {
  const LocationPermissionDenied();
}

/// The fix failed or timed out (`getCurrent` has a 10s limit) — indoors, in a
/// basement, in a dead zone. Retryable, and not the user's fault.
class LocationUnavailable extends LocationOutcome {
  final Object? error;
  const LocationUnavailable([this.error]);
}

/// The user declined the mock-location warning. Distinct from every other
/// case: it means "abort the action", not "proceed without coordinates".
class LocationCancelled extends LocationOutcome {
  const LocationCancelled();
}
