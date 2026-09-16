import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'location_outcome.dart';

enum LocationAccess { granted, denied, deniedForever, serviceDisabled }

class LocationService {
  /// Longest a one-off fix may take before the caller is told it's
  /// unavailable (indoors, a basement) rather than left waiting.
  static const Duration fixTimeout = Duration(seconds: 10);

  /// The `NSLocationTemporaryUsageDescriptionDictionary` key in Info.plist
  /// that explains why an active visit's trail needs precise location.
  static const String _preciseLocationPurposeKey = 'VisitRoute';

  /// Movement (whole meters) below which [watch] reports nothing unless the
  /// caller asks for another threshold.
  static const int defaultDistanceFilterMeters = 5;

  /// Permission + fix in one call, as a [LocationOutcome].
  ///
  /// Prefer this over [ensurePermission] + [getCurrent] at call sites that act
  /// on the result: [getCurrent] throws on timeout ([fixTimeout]), and an uncaught
  /// throw inside an async `onPressed` makes the button appear to do nothing.
  /// Here that becomes an explicit [LocationUnavailable] the caller must
  /// handle.
  Future<LocationOutcome> acquire({
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    // The permission call is inside the try, not before it. `requestPermission`
    // throws `PermissionRequestInProgressException` when a request is already
    // in flight — which is what a double-tap on Start produces — and both it
    // and `isLocationServiceEnabled` can raise `PlatformException`. Left
    // outside, that throw escapes into the async `onPressed` and the button
    // silently does nothing: exactly the failure this method exists to convert
    // into a handled outcome.
    try {
      final permitted = await ensurePermission();
      if (!permitted) return const LocationPermissionDenied();
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

  /// Whether location can be read right now — service on and access granted —
  /// without ever showing a prompt. For code that may run in the background,
  /// where a permission dialog cannot be shown.
  Future<bool> hasPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Like [ensurePermission], but says *why* location is unusable, so a
  /// screen can offer the right fix: ask again, or send the user to Settings
  /// when Android will no longer show the prompt.
  Future<LocationAccess> requestAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceDisabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse =>
        LocationAccess.granted,
      LocationPermission.deniedForever => LocationAccess.deniedForever,
      _ => LocationAccess.denied,
    };
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  /// False when the user granted only approximate location ("Precise
  /// Location" off on iOS, "Approximate" on Android 12+). Unknown counts as
  /// precise, so a platform without the notion never blocks anything.
  Future<bool> isPreciseLocation() async {
    try {
      return await Geolocator.getLocationAccuracy() !=
          LocationAccuracyStatus.reduced;
    } catch (_) {
      return true;
    }
  }

  /// iOS: asks for precise location for this app session, explained by the
  /// `VisitRoute` purpose string in Info.plist. Android has no such prompt
  /// (the user changes it in Settings), so this does nothing there.
  Future<void> requestPreciseLocation() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await Geolocator.requestTemporaryFullAccuracy(
        purposeKey: _preciseLocationPurposeKey,
      );
    } catch (_) {
      // Unsupported or refused: the caller re-checks isPreciseLocation.
    }
  }

  Future<Position> getCurrent({
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) {
    return Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        timeLimit: fixTimeout,
      ),
    );
  }

  Stream<Position> watch({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = defaultDistanceFilterMeters,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    );
  }
}
