import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../constants.dart';
import '../utils/app_log.dart';
import 'location_outcome.dart';

enum LocationAccess { granted, denied, deniedForever, serviceDisabled }

class LocationService {
  /// [platform] and [clock] exist for tests; the app uses the real ones.
  LocationService({
    GeolocatorPlatform? platform,
    DateTime Function()? clock,
    this.timeLimit = fixTimeout,
  })  : _platform = platform,
        _clock = clock ?? DateTime.now;

  final GeolocatorPlatform? _platform;
  final DateTime Function() _clock;

  /// How long [getCurrent] waits. Always [fixTimeout] outside tests.
  final Duration timeLimit;

  GeolocatorPlatform get _geo => _platform ?? GeolocatorPlatform.instance;

  /// Longest a one-off fix may take before the caller is told it's
  /// unavailable (indoors, a basement) rather than left waiting.
  static const Duration fixTimeout = Duration(seconds: 10);

  /// A fix older than this when it arrives is a remembered position, not a
  /// reading taken now. Android's fused provider can hand one out first: on
  /// the emulator one was minutes old and about 600 m away and became a
  /// visit's start, and during a visit one a few seconds old put the End
  /// behind the last trail point. The next live fix follows within a second
  /// (see [_fixInterval]), so waiting for it costs little.
  static const Duration fixMaxAge = Duration(seconds: 2);

  /// A Start/End fix less certain than this keeps [getCurrent] waiting for a
  /// better one. The same bar the trail applies to its points.
  static const double fixMaxAccuracyMeters =
      AppConstants.trailMaxAccuracyMeters;

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

  /// Where the user is now: the evidence recorded on a Start or End.
  ///
  /// Listens until a fix is both live and within [fixMaxAccuracyMeters],
  /// rather than taking the first one delivered, which can be the platform's
  /// cached position (see [fixMaxAge]). When [timeLimit] runs out, the best
  /// fix seen wins, a live coarse one over a precise stale one. With no fix
  /// at all it throws [TimeoutException].
  Future<Position> getCurrent({
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) {
    final done = Completer<Position>();
    final picker = _FixPicker(_clock);
    StreamSubscription<Position>? sub;
    Timer? timer;

    void finish([Object? error]) {
      if (done.isCompleted) return;
      timer?.cancel();
      unawaited(sub?.cancel());
      final fix = picker.best;
      if (fix != null) {
        done.complete(fix);
      } else {
        done.completeError(
          error ?? TimeoutException('No position fix', timeLimit),
        );
      }
    }

    timer = Timer(timeLimit, finish);
    sub = _geo
        .getPositionStream(locationSettings: _oneOffSettings(accuracy))
        .listen(
      (fix) {
        if (picker.offer(fix)) finish();
      },
      onError: finish,
      onDone: finish,
    );
    return done.future;
  }

  /// Android otherwise asks for a fix every 5 s, so a skipped fix would cost
  /// up to 5 s of waiting.
  static LocationSettings _oneOffSettings(LocationAccuracy accuracy) =>
      defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(accuracy: accuracy, intervalDuration: _fixInterval)
          : LocationSettings(accuracy: accuracy);

  static const Duration _fixInterval = Duration(seconds: 1);

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

/// Picks the Start/End fix out of a position stream, for
/// [LocationService.getCurrent].
class _FixPicker {
  _FixPicker(this._clock);

  final DateTime Function() _clock;

  /// The fix to use if listening stops now.
  Position? best;
  bool _bestLive = false;

  Position? _last;
  Duration _lastSkew = Duration.zero;

  /// Takes one fix; true when it is good enough to stop listening.
  bool offer(Position fix) {
    final skew = _clock().difference(fix.timestamp);
    final live =
        skew.abs() <= LocationService.fixMaxAge || _continuesStream(fix, skew);
    _last = fix;
    _lastSkew = skew;

    final precise = _isPrecise(fix);
    appLog(
      '[LocationService] fix age=${skew.inMilliseconds}ms '
      'accuracy=${fix.accuracy}m live=$live precise=$precise',
    );
    final held = best;
    final rank = _rank(live: live, precise: precise);
    final heldRank =
        held == null ? -1 : _rank(live: _bestLive, precise: _isPrecise(held));
    if (rank > heldRank ||
        (rank == heldRank && fix.timestamp.isAfter(held!.timestamp))) {
      best = fix;
      _bestLive = live;
    }
    return live && precise;
  }

  /// A device clock that is wrong makes every fix look old. A live stream
  /// still shows through it: each fix is newer than the one before, and both
  /// sit the same distance from the clock. A remembered fix followed by a
  /// live one does not, so the remembered one is never taken for live.
  bool _continuesStream(Position fix, Duration skew) {
    final last = _last;
    return last != null &&
        fix.timestamp.isAfter(last.timestamp) &&
        (skew - _lastSkew).abs() <= LocationService.fixMaxAge;
  }

  /// Android reports 0 when a fix carries no accuracy; that is not a reason
  /// to keep waiting.
  static bool _isPrecise(Position fix) =>
      fix.accuracy <= LocationService.fixMaxAccuracyMeters;

  /// Live matters more than precise: a coarse fix from now beats an exact
  /// one from minutes ago.
  static int _rank({required bool live, required bool precise}) =>
      (live ? 2 : 0) + (precise ? 1 : 0);
}
