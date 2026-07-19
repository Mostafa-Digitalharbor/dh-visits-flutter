import 'package:geolocator/geolocator.dart';

import 'location_outcome.dart';

class LocationService {
  /// Permission + fix in one call, as a [LocationOutcome].
  ///
  /// Prefer this over [ensurePermission] + [getCurrent] at call sites that act
  /// on the result: [getCurrent] throws on timeout (10s), and an uncaught
  /// throw inside an async `onPressed` makes the button appear to do nothing.
  /// Here that becomes an explicit [LocationUnavailable] the caller must
  /// handle.
  Future<LocationOutcome> acquire({
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    final permitted = await ensurePermission();
    if (!permitted) return const LocationPermissionDenied();
    try {
      return LocationOk.from(await getCurrent(accuracy: accuracy));
    } catch (e) {
      return LocationUnavailable(e);
    }
  }

  /// Ensures the user has granted location permission and the service is enabled.
  /// Returns true if usable, false otherwise.
  Future<bool> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  Future<Position> getCurrent({
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) {
    return Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        timeLimit: const Duration(seconds: 10),
      ),
    );
  }

  Stream<Position> watch({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 5,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    );
  }
}
