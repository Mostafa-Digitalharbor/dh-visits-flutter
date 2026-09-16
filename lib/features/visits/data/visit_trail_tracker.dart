import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/constants.dart';
import '../../../core/location/location_service.dart';
import '../../../core/location/visit_location_channel.dart';
import '../../../core/network/connectivity_status.dart';
import '../../../core/network/pending_actions_queue.dart';
import '../../../core/network/server_clock.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/utils/distance.dart';
import '../domain/visit_action.dart';
import 'models/visit.dart';
import 'models/visit_location_log.dart';
import 'visit_tracking_consent.dart';
import 'visits_repository.dart';

/// The user-visible labels of the Android tracking notification.
typedef TrailNotificationLabels = ({String title, String text});

/// Why a visit that should be recorded is not being recorded right now.
enum TrailPause {
  /// This install has not shown (or the user declined) the tracking
  /// disclosure.
  consent,

  /// Location access is missing or location services are off.
  permission,

  /// The platform refused to start capture (e.g. the app was in the
  /// background). Retried when the app comes to the foreground.
  unavailable,
}

/// What the trail capture is doing, for the active-visit bar.
class TrailCaptureStatus extends Equatable {
  /// The visit whose trail is being recorded — one the server confirmed as
  /// `in_progress` — or null when nothing is.
  final int? visitId;

  /// Why [visitId] is not actually being recorded; null while it is.
  final TrailPause? paused;

  /// Fixes recorded on this device and not yet accepted by the server.
  final int pending;

  const TrailCaptureStatus({this.visitId, this.paused, this.pending = 0});

  bool get isRecording => visitId != null && paused == null;

  @override
  List<Object?> get props => [visitId, paused, pending];
}

/// Records the GPS trail of the visit that is in progress — and nothing else —
/// and pushes it to the server in batches.
///
/// **Only while a visit is in progress.** Capture starts only once the server
/// has confirmed that a visit entered `in_progress` ([start], called with the
/// Start response, a replayed offline Start, or a server read after a restart)
/// and stops the moment the visit is ended, cancelled, found no longer in
/// progress, or the user signs out ([stop], [verify], [suspend]). Nothing is
/// recorded before Start, between visits or after End. A push notification can
/// only make the tracker re-check — never start it.
///
/// **One location source.** On Android and iOS positions come from the native
/// capture ([VisitLocationChannel]: a `location` foreground service /
/// background location updates), which keeps recording with the app in the
/// background or the screen locked and journals each fix to disk with the
/// visit it belongs to. This class moves them into its upload buffer
/// ([drain]). Elsewhere a foreground-only position stream stands in.
///
/// **Buffer first, send second.** Every fix lands in a SharedPreferences
/// buffer, keyed by visit and signed-in account, before anything is sent, so a
/// fix survives the app being killed and a dead zone. Points taken during a
/// visit still upload after it ended — the server accepts them as long as
/// their `logged_at` (the real fix time, read against the server's clock)
/// falls inside the start–end window — but no fix taken after the local End
/// ever enters the buffer.
///
/// It is deliberately *not* a bloc: the trail UI reads the server's copy
/// through `VisitTrailCubit`; this class only feeds it. [status], [pendingCount]
/// and [revision] let a screen show what is happening.
class VisitTrailTracker with WidgetsBindingObserver {
  final SharedPreferences prefs;
  final VisitsRepository repository;
  final LocationService locationService;
  final ConnectivityStatus connectivity;
  final VisitLocationChannel channel;

  /// Never captures without it; see [TrailPause.consent].
  final VisitTrackingConsent consent;

  /// Localized title/text of the Android tracking notification, read each
  /// time capture starts so it follows the app's language.
  final TrailNotificationLabels Function() notificationLabels;

  /// Consulted before a flush (points of a visit whose Start is still queued
  /// have nothing to attach to server-side) and before tracking is restored
  /// (a visit whose End is queued must not be recorded any more).
  final PendingActionsQueue Function()? pendingActions;

  /// Re-expresses each fix's device-clock timestamp on the server's clock, so
  /// `logged_at` is comparable with the `start_datetime`/`end_datetime` the
  /// server stamps. Null (in tests) sends the device time unchanged.
  final ServerClock? serverClock;

  /// Stable per-install id sent as each point's `device_id`, the same one the
  /// FCM registration uses.
  final Future<String?> Function()? deviceId;

  /// Who is signed in, as `server|uid`. Buffered points and the active-visit
  /// marker carry it, so one account's points are never sent — or tracking
  /// resumed — under another. Null resolver (tests): unscoped.
  final Future<String?> Function()? ownerResolver;

  VisitTrailTracker({
    required this.prefs,
    required this.repository,
    required this.locationService,
    required this.connectivity,
    required this.notificationLabels,
    VisitLocationChannel? channel,
    VisitTrackingConsent? consent,
    this.pendingActions,
    this.serverClock,
    this.deviceId,
    this.ownerResolver,
  }) : channel = channel ?? const VisitLocationChannel(),
       consent = consent ?? VisitTrackingConsent(prefs) {
    WidgetsBinding.instance.addObserver(this);
    unawaited(_purgeLegacy());
    _visitId = _readMarker()?.visitId;
    _publish();
    connectivity.addListener(_onConnectivity);
  }

  static const String _bufferKey = StorageKeys.trailBuffer;
  static const String _markerKey = StorageKeys.trailActiveVisit;
  static const String _seqKey = StorageKeys.trailNativeSeq;
  static const String _endedKey = StorageKeys.trailEndedVisits;

  /// Start boundary slack. The server refuses a point that predates
  /// `start_datetime`; the clock offset is known to about a second, so fixes
  /// in the first moments are left out rather than refused and reported.
  static const Duration _startSlack = Duration(seconds: 2);

  /// Refusals that say the *session* is unusable, not the points.
  static const _sessionProblems = {
    ApiErrorCode.unauthorized,
    ApiErrorCode.invalidCredentials,
    ApiErrorCode.sessionRestoreFailed,
    ApiErrorCode.databaseNotFound,
  };

  final ValueNotifier<TrailCaptureStatus> _status =
      ValueNotifier<TrailCaptureStatus>(const TrailCaptureStatus());
  ValueListenable<TrailCaptureStatus> get status => _status;

  /// Fixes captured but not yet accepted by the server.
  final ValueNotifier<int> _pendingCount = ValueNotifier<int>(0);
  ValueListenable<int> get pendingCount => _pendingCount;

  /// Bumped every time a flush actually lands points on the server, so an open
  /// trail screen can refetch instead of polling blindly.
  final ValueNotifier<int> _revision = ValueNotifier<int>(0);
  ValueListenable<int> get revision => _revision;

  /// Fires when the server permanently refused buffered fixes. They are gone
  /// from the buffer by the time this fires: whoever listens owes the user an
  /// explanation, exactly as with [PendingActionsQueue.onDropped].
  final StreamController<int> _dropped = StreamController<int>.broadcast();
  Stream<int> get onPointsDropped => _dropped.stream;

  int? _visitId;
  TrailPause? _paused;
  String? _deviceIdValue;
  bool _disposed = false;

  /// Tracking was restored from the local marker while the server could not
  /// be asked; it is confirmed (or stopped) once the network is back.
  bool _needsServerCheck = false;

  /// Whether this process has decided what to record — a Start, or the
  /// start-up [resume] / [resumeUnverified]. Until then an app resume must not
  /// bring capture back from the marker alone: the visit may have been ended
  /// elsewhere while the app was not running.
  bool _settled = false;
  DateTime? _lastVerify;

  Timer? _drainTimer;
  Timer? _flushTimer;
  Future<void>? _inFlight;
  Future<void>? _draining;

  // Foreground-stream stand-in where there is no native capture.
  StreamSubscription<Position>? _fallback;
  Position? _lastFallback;

  /// Bumped whenever the fallback stream is deliberately torn down, so a
  /// subscribe still waiting on the permission check gives up.
  int _streamEpoch = 0;

  /// The visit being recorded, or null.
  int? get activeVisitId => _visitId;
  bool get isTracking => _visitId != null;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Records [visitId]'s trail. Call only once the server has confirmed the
  /// visit is `in_progress`; [startedAt] is the server's `start_datetime`
  /// (fixes before it are ignored), [seedLatitude]/[seedLongitude] the
  /// position the Start action already put on the trail.
  ///
  /// Safe to call again for the visit already being recorded (it only makes
  /// sure capture is running). Starting another visit stops the previous one
  /// first, so no fix can be attributed to the wrong visit.
  Future<void> start(
    int visitId, {
    DateTime? startedAt,
    double? seedLatitude,
    double? seedLongitude,
  }) async {
    if (_disposed) return;
    final owner = await _resolveOwner();
    final current = _readMarker();
    if (current != null && current.visitId != visitId) {
      await stop();
    }
    final same = current?.visitId == visitId ? current : null;
    final since = _deviceTimeOf(startedAt)?.add(_startSlack) ??
        same?.since ??
        DateTime.now();
    await _writeMarker(_Marker(
      visitId: visitId,
      owner: owner,
      since: since,
      seedLatitude: seedLatitude ?? same?.seedLatitude,
      seedLongitude: seedLongitude ?? same?.seedLongitude,
    ));
    await _forgetEnded(visitId);
    _visitId = visitId;
    _needsServerCheck = false;
    _settled = true;
    appLog('[VisitTrailTracker] recording visit $visitId');
    await _resolveDeviceId();
    await _ensureCapture();
    _syncTimers();
    _publish();
    unawaited(drain().then((_) => flushNow()));
  }

  /// Stops recording: capture is shut down first, then everything recorded up
  /// to now is moved into the buffer and — with [flush], the default — sent,
  /// so the tail of the route is on the server before the End goes out.
  ///
  /// [endedAt] is when the visit really ended, when the server says it ended
  /// earlier than now (elsewhere, while this device was not listening): fixes
  /// taken after it are discarded instead of being sent and refused.
  Future<void> stop({bool flush = true, DateTime? endedAt}) async {
    final marker = _readMarker();
    final visitId = marker?.visitId ?? _visitId;
    await _stopCapture();
    if (visitId != null) {
      final now = DateTime.now().toUtc();
      final end = endedAt == null || endedAt.isAfter(now) ? now : endedAt;
      await _rememberEnded(visitId, end);
      if (endedAt != null) await _discardAfter(visitId, _serverTime(end));
    }
    await drain();
    await _clearMarker();
    if (visitId != null) {
      appLog('[VisitTrailTracker] stopped recording visit $visitId');
    }
    _visitId = null;
    _paused = null;
    _needsServerCheck = false;
    _syncTimers();
    _publish();
    if (flush) await flushNow();
  }

  /// Restores tracking after an app start or sign-in from the server's answer:
  /// [running] is the caller's visit that is `in_progress`, or null.
  ///
  /// Recording continues only for that visit, and only if no End for it is
  /// waiting in the offline queue. Anything else stops capture — including a
  /// native capture left running by a previous process — and uploads what is
  /// still buffered, which is how a visit ended on another device still gets
  /// its dead-zone fixes uploaded.
  Future<void> resume(Visit? running) async {
    _settled = true;
    final owner = await _resolveOwner();
    final marker = _readMarker();
    if (running == null ||
        !running.isInProgress ||
        _hasQueued(running.id, VisitAction.end)) {
      final ended = marker == null || marker.visitId == running?.id
          ? null
          : await _serverEnd(marker.visitId);
      await stop(flush: false, endedAt: ended);
      unawaited(flushNow(probe: true));
      return;
    }
    if (marker != null &&
        (marker.owner != owner || marker.visitId != running.id)) {
      // Recorded under another account on this phone, or a visit that has
      // finished since (the server now runs another one).
      final ended = marker.owner == owner
          ? await _serverEnd(marker.visitId)
          : null;
      await stop(flush: false, endedAt: ended);
    }
    await start(running.id, startedAt: running.startDatetime);
  }

  /// When the server says [visitId] ended, on the device clock; null when it
  /// has not ended or cannot be read.
  Future<DateTime?> _serverEnd(int visitId) async {
    try {
      final visit = await repository.getVisit(visitId);
      return _deviceTimeOf(visit?.endDatetime);
    } catch (e) {
      appLog('[VisitTrailTracker] end of visit $visitId unknown: $e');
      return null;
    }
  }

  /// Restores tracking from the local marker when the server could not be
  /// asked (offline at start-up). The server is asked again as soon as the
  /// network is back, and capture stops if the visit is no longer running.
  Future<void> resumeUnverified() async {
    _settled = true;
    final owner = await _resolveOwner();
    final marker = _readMarker();
    if (marker == null) {
      await _stopCapture();
      return;
    }
    if (marker.owner != owner ||
        _hasQueued(marker.visitId, VisitAction.end)) {
      await stop(flush: false);
      return;
    }
    _visitId = marker.visitId;
    _needsServerCheck = true;
    await _resolveDeviceId();
    await _ensureCapture();
    _syncTimers();
    _publish();
  }

  /// Asks the server whether the visit being recorded is still in progress and
  /// stops recording when it is not (ended or cancelled elsewhere, rescheduled,
  /// deleted). Only ever stops — never starts — so a push notification or a
  /// refused batch can safely trigger it. Throttled unless [force].
  Future<void> verify({bool force = false}) async {
    final id = _visitId;
    if (id == null) return;
    final now = DateTime.now();
    final last = _lastVerify;
    if (!force &&
        last != null &&
        now.difference(last) < AppConstants.trailVerifyInterval) {
      return;
    }
    _lastVerify = now;
    final Visit? visit;
    try {
      visit = await repository.getVisit(id);
    } on ApiException catch (e) {
      // Only an answer about the visit itself ends the recording; a network or
      // session problem says nothing about it.
      if (e.code != ApiErrorCode.notFound &&
          e.code != ApiErrorCode.permissionDenied) {
        return;
      }
      if (_visitId == id) {
        appLog('[VisitTrailTracker] visit $id unreadable (${e.code}); stopping');
        await stop();
      }
      return;
    } catch (e) {
      appLog('[VisitTrailTracker] could not verify visit $id: $e');
      return;
    }
    if (_visitId != id) return;
    if (visit == null || !visit.isInProgress) {
      appLog('[VisitTrailTracker] visit $id is ${visit?.state.name ?? 'gone'} '
          'on the server; stopping');
      await stop(endedAt: _deviceTimeOf(visit?.endDatetime));
    }
  }

  /// A Start that was held in the offline queue reached the server. Recording
  /// begins only if the server now reports the visit `in_progress` and no End
  /// for it is queued behind the Start.
  Future<void> onQueuedStartSynced(int visitId) async {
    if (_hasQueued(visitId, VisitAction.end)) return;
    final current = _visitId;
    if (current != null && current != visitId) return;
    final Visit? visit;
    try {
      visit = await repository.getVisit(visitId);
    } catch (e) {
      appLog('[VisitTrailTracker] replayed start of $visitId unconfirmed: $e');
      return;
    }
    if (visit == null || !visit.isInProgress) return;
    if (_hasQueued(visitId, VisitAction.end)) return;
    await start(visitId, startedAt: visit.startDatetime);
  }

  /// Signing out: capture stops (nobody is tracked while signed out) and what
  /// was recorded is pushed while the session is still valid. The visit stays
  /// in progress on the server; the next sign-in asks the server again.
  Future<void> suspend() => stop();

  /// Tries again to capture the visit being recorded — after the user agreed
  /// to the disclosure or granted location access.
  Future<void> retry() async {
    if (_visitId == null) return;
    await _ensureCapture();
    _syncTimers();
    _publish();
  }

  @override
  // ignore: avoid_renaming_method_parameters
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    switch (lifecycle) {
      case AppLifecycleState.resumed:
        if (_visitId != null && _settled) {
          // The system may have killed the capture with the process, or the
          // user granted access in Settings meanwhile.
          unawaited(_ensureCapture().then((_) => _publish()));
          unawaited(verify());
        }
        unawaited(drain().then((_) => flushNow(probe: true)));
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        if (!channel.isAvailable) _closeFallback();
        unawaited(drain().then((_) => flushNow()));
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _onConnectivity() {
    if (!connectivity.isOnline) return;
    if (_needsServerCheck) unawaited(_recheckServer());
    unawaited(flushNow());
  }

  Future<void> _recheckServer() async {
    if (!_needsServerCheck) return;
    final Visit? running;
    try {
      running = await repository.myRunningVisit();
    } catch (e) {
      appLog('[VisitTrailTracker] running visit still unknown: $e');
      return;
    }
    await resume(running);
  }

  // ---------------------------------------------------------------------------
  // Capture
  // ---------------------------------------------------------------------------

  bool get _foreground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  /// Makes sure the visit in the marker is being captured, or records why it
  /// cannot be. Never throws.
  Future<void> _ensureCapture() async {
    final marker = _readMarker();
    if (marker == null) return;
    if (!consent.accepted) {
      await _stopCapture();
      _paused = TrailPause.consent;
      return;
    }
    if (channel.isAvailable) {
      try {
        final st = await channel.status();
        if (st.active && st.running && st.visitId == marker.visitId) {
          _paused = null;
          return;
        }
        if (!await locationService.hasPermission()) {
          _paused = TrailPause.permission;
          return;
        }
        final labels = notificationLabels();
        await channel.start(
          visitId: marker.visitId,
          since: marker.since,
          minDistanceMeters: AppConstants.trailMinDistanceMeters,
          minInterval: AppConstants.trailMinInterval,
          maxAccuracyMeters: AppConstants.trailMaxAccuracyMeters,
          title: labels.title,
          text: labels.text,
          seedLatitude: marker.seedLatitude,
          seedLongitude: marker.seedLongitude,
        );
        _paused = null;
      } catch (e) {
        appLog('[VisitTrailTracker] could not start location capture: $e');
        _paused = TrailPause.unavailable;
      }
      return;
    }
    if (!await locationService.hasPermission()) {
      _paused = TrailPause.permission;
      return;
    }
    _paused = null;
    if (_foreground) _subscribeFallback();
  }

  Future<void> _stopCapture() async {
    _closeFallback();
    if (!channel.isAvailable) return;
    try {
      await channel.stop();
    } catch (e) {
      appLog('[VisitTrailTracker] could not stop location capture: $e');
    }
  }

  void _subscribeFallback() {
    if (_fallback != null) return;
    final epoch = _streamEpoch;
    _fallback = locationService
        .watch(distanceFilter: AppConstants.trailMinDistanceMeters.round())
        .listen(
          (pos) {
            if (epoch == _streamEpoch) _onFallbackPosition(pos);
          },
          onError: (Object e) =>
              appLog('[VisitTrailTracker] position stream error: $e'),
          cancelOnError: false,
        );
  }

  void _closeFallback() {
    _streamEpoch++;
    final sub = _fallback;
    _fallback = null;
    _lastFallback = null;
    unawaited(sub?.cancel());
  }

  /// The native capture's acceptance rules, for the foreground stream.
  void _onFallbackPosition(Position pos) {
    final marker = _readMarker();
    if (marker == null || _visitId != marker.visitId) return;
    // A cached position replayed when the stream opened predates the visit.
    if (pos.timestamp.isBefore(marker.since)) return;
    final accuracy = pos.accuracy;
    if (accuracy > AppConstants.trailMaxAccuracyMeters) return;
    final last = _lastFallback;
    if (last != null) {
      if (!pos.timestamp.isAfter(last.timestamp)) return;
      final moved = haversineMeters(
        last.latitude,
        last.longitude,
        pos.latitude,
        pos.longitude,
      );
      if (moved < AppConstants.trailMinDistanceMeters) return;
      if (pos.timestamp.difference(last.timestamp) <
              AppConstants.trailMinInterval &&
          moved < AppConstants.trailBurstDistanceMeters) {
        return;
      }
    }
    _lastFallback = pos;
    final point = TrailPoint(
      latitude: pos.latitude,
      longitude: pos.longitude,
      // The fix's own time, not the upload time: this is the field the server
      // orders and measures the trail by.
      loggedAt: _serverTime(pos.timestamp),
      accuracy: accuracy > 0 ? accuracy : null,
      altitude: pos.altitude,
      speed: pos.speed >= 0 ? pos.speed : null,
      heading: pos.heading >= 0 ? pos.heading : null,
      deviceId: _deviceIdValue,
    );
    unawaited(_guard('buffer fix', () async {
      await _bufferAll([
        _BufferedPoint(visitId: marker.visitId, owner: marker.owner, point: point),
      ]);
    }));
  }

  // ---------------------------------------------------------------------------
  // Draining the native journal
  // ---------------------------------------------------------------------------

  /// Moves every fix the native capture journalled into the upload buffer.
  /// Waits for a drain already running and then drains again, so a caller
  /// that needs "everything up to now" (ending a visit) gets it. Never throws.
  Future<void> drain() async {
    while (_draining != null) {
      await _draining;
    }
    final run = _guard('drain capture journal', _takeCapturedFixes);
    _draining = run;
    try {
      await run;
    } finally {
      _draining = null;
    }
  }

  Future<void> _takeCapturedFixes() async {
    if (!channel.isAvailable) return;
    final owner = await _resolveOwner();
    while (true) {
      final fixes = await channel.read(max: AppConstants.trailMaxDrain);
      if (fixes.isEmpty) return;
      var lastSeq = prefs.getInt(_seqKey) ?? 0;
      final newest = fixes.map((f) => f.seq).reduce((a, b) => a > b ? a : b);
      if (newest < lastSeq) {
        // Everything in the journal is older than what was already taken:
        // the native counter started over (its storage was reset while ours
        // was not). A replay after a crash before the acknowledgement always
        // ends exactly at [lastSeq], so this is never a fix taken twice.
        appLog('[VisitTrailTracker] capture journal restarted at $newest '
            '(was $lastSeq)');
        lastSeq = 0;
      }
      final ended = _readEnded();
      final taken = <_BufferedPoint>[];
      var maxSeq = lastSeq;
      for (final f in fixes) {
        if (f.seq > maxSeq) maxSeq = f.seq;
        if (f.seq <= lastSeq) continue;
        final endedAt = ended[f.visitId];
        if (endedAt != null && f.deviceTime.isAfter(endedAt)) {
          appLog('[VisitTrailTracker] fix #${f.seq} postdates the end of '
              'visit ${f.visitId}; discarded');
          continue;
        }
        taken.add(_BufferedPoint(
          visitId: f.visitId,
          owner: owner,
          point: TrailPoint(
            latitude: f.latitude,
            longitude: f.longitude,
            // The fix's own time, only re-read against the server's clock.
            loggedAt: _serverTime(f.deviceTime),
            accuracy: (f.accuracy ?? 0) > 0 ? f.accuracy : null,
            altitude: f.altitude,
            speed: (f.speed ?? -1) >= 0 ? f.speed : null,
            heading: (f.heading ?? -1) >= 0 ? f.heading : null,
            deviceId: _deviceIdValue,
          ),
        ));
      }
      // Buffer, then remember, then acknowledge: a crash anywhere in between
      // replays the drain instead of losing a fix, and the sequence check keeps
      // the replay from buffering a fix twice.
      if (taken.isNotEmpty) await _bufferAll(taken);
      await prefs.setInt(_seqKey, maxSeq);
      await channel.ack(maxSeq);
      if (fixes.length < AppConstants.trailMaxDrain) return;
    }
  }

  // ---------------------------------------------------------------------------
  // Buffer
  // ---------------------------------------------------------------------------

  Future<void> _bufferAll(List<_BufferedPoint> points) async {
    final buffer = _readBuffer();
    final known = {for (final b in buffer) b.key};
    for (final p in points) {
      if (known.add(p.key)) buffer.add(p);
    }
    // Hard ceiling so a phone that spends days offline can't grow the
    // preferences blob without bound. The oldest fixes go first.
    if (buffer.length > AppConstants.trailMaxBufferedPoints) {
      final overflow = buffer.length - AppConstants.trailMaxBufferedPoints;
      buffer.removeRange(0, overflow);
      appLog('[VisitTrailTracker] buffer full; dropped $overflow oldest fix(es)');
      _dropped.add(overflow);
    }
    await _writeBuffer(buffer);
    _syncTimers();
    if (buffer.length >= AppConstants.trailFlushBatchSize) {
      unawaited(flushNow());
    }
  }

  /// Drops buffered fixes of [visitId] dated after [serverEnd] (server clock):
  /// taken after the visit ended elsewhere, they could only come back refused.
  Future<void> _discardAfter(int visitId, DateTime serverEnd) async {
    final buffer = _readBuffer();
    final kept = [
      for (final b in buffer)
        if (b.visitId != visitId || !b.point.loggedAt.isAfter(serverEnd)) b,
    ];
    if (kept.length == buffer.length) return;
    appLog('[VisitTrailTracker] discarded ${buffer.length - kept.length} '
        'fix(es) of visit $visitId taken after it ended');
    await _writeBuffer(kept);
  }

  // ---------------------------------------------------------------------------
  // Flushing
  // ---------------------------------------------------------------------------

  /// Pushes the signed-in account's buffered points to the server, one batch
  /// run per visit.
  ///
  /// When a flush is already running this waits for it and then flushes again,
  /// so End, which awaits this, really gets the tail of the route out.
  ///
  /// [probe] sends even while [ConnectivityStatus] reads offline: that flag
  /// only turns back to online after *some* request succeeds, so a quiet app
  /// would otherwise keep the route on the device long after the network
  /// returned. Timer and app-resume flushes probe; point-count triggers don't.
  ///
  /// Never throws.
  Future<void> flushNow({bool probe = false}) async {
    while (_inFlight != null) {
      await _inFlight;
    }
    final run = _flushAll(probe: probe);
    _inFlight = run;
    try {
      await run;
    } finally {
      _inFlight = null;
    }
  }

  Future<void> _flushAll({required bool probe}) async {
    try {
      final buffer = _readBuffer();
      if (buffer.isEmpty) return;
      if (!connectivity.isOnline && !probe) return;
      final owner = await _resolveOwner();
      if (ownerResolver != null && owner == null) return; // signed out

      final byVisit = <int, List<_BufferedPoint>>{};
      final others = <_BufferedPoint>[];
      for (final b in buffer) {
        if (ownerResolver != null && b.owner != null && b.owner != owner) {
          others.add(b); // another account's; kept for its next sign-in
          continue;
        }
        byVisit.putIfAbsent(b.visitId, () => []).add(b);
      }

      final survivors = <_BufferedPoint>[...others];
      var landed = false;
      var droppedTotal = 0;
      var refused = false;

      for (final entry in byVisit.entries) {
        final visitId = entry.key;
        // A Start still waiting in the offline queue means the server has this
        // visit as `approved`: every point would be refused. Hold them until
        // the queue has replayed the Start.
        if (_hasQueued(visitId, VisitAction.start)) {
          survivors.addAll(entry.value);
          continue;
        }
        final result = await _flush(visitId, entry.value);
        survivors.addAll(result.keep);
        landed = landed || result.landed;
        droppedTotal += result.dropped;
        refused = refused || (result.refused && visitId == _visitId);
      }

      // Points buffered while the network calls were in flight are still only
      // on disk: re-read and keep them, or this write would erase them.
      final sentKeys = {for (final b in buffer) b.key};
      final arrivedMeanwhile =
          _readBuffer().where((b) => !sentKeys.contains(b.key));
      await _writeBuffer([...survivors, ...arrivedMeanwhile]);
      if (droppedTotal > 0) _dropped.add(droppedTotal);
      if (landed) _revision.value++;
      _syncTimers();
      // The server refused points of the visit being recorded: it may have
      // been ended or cancelled elsewhere (throttled, like every check).
      if (refused) unawaited(verify());
    } catch (e) {
      appLog('[VisitTrailTracker] flush failed: $e');
    }
  }

  bool _hasQueued(int visitId, VisitAction action) {
    final queue = pendingActions?.call();
    if (queue == null) return false;
    try {
      return queue.pending
          .any((a) => a.visitId == visitId && a.action == action);
    } catch (_) {
      return false;
    }
  }

  /// Sends one visit's buffered points, in batches until they're gone or the
  /// server stops taking them.
  Future<_FlushOutcome> _flush(int visitId, List<_BufferedPoint> points) async {
    // Oldest first, so a run that stops early still leaves a contiguous path
    // behind on the server and a contiguous remainder in the buffer.
    points.sort((a, b) => a.point.loggedAt.compareTo(b.point.loggedAt));

    var remaining = points;
    final keep = <_BufferedPoint>[];
    var landed = false;
    var dropped = 0;
    var refused = false;

    while (remaining.isNotEmpty) {
      final batch = remaining.take(AppConstants.trailMaxBatchSize).toList();
      final rest = remaining.skip(batch.length).toList();
      try {
        final result = await repository.logLocations(visitId, [
          for (final b in batch) b.point,
        ]);

        // Partial success is the normal case: `rejected[].index` is the
        // position in the array just sent, and every index *not* listed was
        // created. Accepted points simply leave the buffer.
        final refusedAt = {for (final r in result.rejected) r.index: r};
        final serverNow = serverClock?.now() ?? DateTime.now().toUtc();
        for (var i = 0; i < batch.length; i++) {
          final refusal = refusedAt[i];
          if (refusal == null) continue;
          refused = true;
          final b = batch[i];
          // Every refusal is permanent except "cannot be dated in the future",
          // which time itself cures: a fix still ahead of the server's clock is
          // kept and retried (bounded). Anything else (out of range,
          // unparseable, before the start, after the end) would be refused
          // identically forever, so it is dropped — and reported.
          if (b.point.loggedAt.isAfter(serverNow) &&
              b.attempts + 1 < AppConstants.trailMaxFlushAttempts) {
            keep.add(b.withAttempt());
            appLog('[VisitTrailTracker] visit $visitId point $i dated ahead '
                'of the server; retrying later: ${refusal.error}');
          } else {
            dropped++;
            appLog('[VisitTrailTracker] visit $visitId point $i '
                '(${b.point.loggedAt.toIso8601String()}) refused: '
                '${refusal.error}');
          }
        }
        landed = landed || result.created > 0;
        remaining = rest;
      } on ApiException catch (e) {
        if (e.isTransient || _sessionProblems.contains(e.code)) {
          // Unreachable again mid-drain, or the session needs a new sign-in:
          // nothing is wrong with the points. Keep what is left, retry later.
          return _FlushOutcome([...keep, ...remaining], landed, dropped, refused);
        }
        // The whole call was refused (the visit moved on, rights changed).
        // Retried a bounded number of times rather than forever or never.
        final retried = [
          for (final b in remaining)
            if (b.attempts + 1 < AppConstants.trailMaxFlushAttempts)
              b.withAttempt(),
        ];
        dropped += remaining.length - retried.length;
        appLog('[VisitTrailTracker] visit $visitId batch refused '
            '(${e.code} ${e.serverMessage ?? ''}); keeping ${retried.length}, '
            'dropping ${remaining.length - retried.length}');
        return _FlushOutcome([...keep, ...retried], landed, dropped, true);
      }
    }
    return _FlushOutcome(keep, landed, dropped, refused);
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  Future<void> _purgeLegacy() async {
    for (final key in StorageKeys.legacyLocationKeys) {
      try {
        if (prefs.containsKey(key)) await prefs.remove(key);
      } catch (_) {
        // Nothing to salvage from a legacy key; a failed removal is retried
        // on the next start.
      }
    }
  }

  List<_BufferedPoint> _readBuffer() {
    final String? raw;
    try {
      raw = prefs.getString(_bufferKey);
    } catch (_) {
      return [];
    }
    if (raw == null || raw.isEmpty) return [];
    final List<dynamic> list;
    try {
      list = jsonDecode(raw) as List;
    } catch (_) {
      return [];
    }
    // Entry by entry: one unreadable record must not discard a whole visit's
    // worth of collected path.
    final out = <_BufferedPoint>[];
    for (final m in list.whereType<Map>()) {
      final p = _BufferedPoint.tryFromJson(Map<String, dynamic>.from(m));
      if (p != null) out.add(p);
    }
    return out;
  }

  Future<void> _writeBuffer(List<_BufferedPoint> points) async {
    if (points.isEmpty) {
      await prefs.remove(_bufferKey);
    } else {
      await prefs.setString(
        _bufferKey,
        jsonEncode([for (final p in points) p.toJson()]),
      );
    }
    _pendingCount.value = points.length;
    _publish();
  }

  _Marker? _readMarker() {
    try {
      final raw = prefs.getString(_markerKey);
      if (raw == null || raw.isEmpty) return null;
      return _Marker.tryFromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeMarker(_Marker marker) =>
      prefs.setString(_markerKey, jsonEncode(marker.toJson()));

  Future<void> _clearMarker() => prefs.remove(_markerKey);

  /// visit id → the device time its local recording ended.
  Map<int, DateTime> _readEnded() {
    try {
      final raw = prefs.getString(_endedKey);
      if (raw == null || raw.isEmpty) return {};
      final map = jsonDecode(raw) as Map;
      return {
        for (final e in map.entries)
          if (int.tryParse(e.key.toString()) case final id?)
            if (e.value is num)
              id: DateTime.fromMillisecondsSinceEpoch(
                (e.value as num).toInt(),
                isUtc: true,
              ),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeEnded(Map<int, DateTime> ended) => prefs.setString(
        _endedKey,
        jsonEncode({
          for (final e in ended.entries)
            '${e.key}': e.value.millisecondsSinceEpoch,
        }),
      );

  Future<void> _rememberEnded(int visitId, DateTime at) async {
    final ended = _readEnded()..remove(visitId);
    ended[visitId] = at.toUtc();
    while (ended.length > AppConstants.trailMaxEndedVisits) {
      ended.remove(ended.keys.first);
    }
    await _writeEnded(ended);
  }

  Future<void> _forgetEnded(int visitId) async {
    final ended = _readEnded();
    if (ended.remove(visitId) != null) await _writeEnded(ended);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Drain timer while a visit is recorded; flush timer while one is recorded
  /// or anything is still buffered.
  void _syncTimers() {
    if (_disposed) return;
    final recording = _visitId != null;
    if (recording && channel.isAvailable) {
      _drainTimer ??= Timer.periodic(
        AppConstants.trailDrainInterval,
        (_) => unawaited(drain()),
      );
    } else {
      _drainTimer?.cancel();
      _drainTimer = null;
    }
    if (recording || _pendingCount.value > 0) {
      _flushTimer ??= Timer.periodic(
        AppConstants.trailFlushInterval,
        (_) => unawaited(drain().then((_) => flushNow(probe: true))),
      );
    } else {
      _flushTimer?.cancel();
      _flushTimer = null;
    }
  }

  void _publish() {
    if (_disposed) return;
    _pendingCount.value = _readBuffer().length;
    _status.value = TrailCaptureStatus(
      visitId: _visitId,
      paused: _visitId == null ? null : _paused,
      pending: _pendingCount.value,
    );
  }

  Future<String?> _resolveOwner() async {
    final resolver = ownerResolver;
    if (resolver == null) return null;
    try {
      return await resolver();
    } catch (e) {
      appLog('[VisitTrailTracker] signed-in user unknown: $e');
      return null;
    }
  }

  Future<void> _resolveDeviceId() async {
    if (_deviceIdValue != null || deviceId == null) return;
    try {
      _deviceIdValue = await deviceId!();
    } catch (e) {
      appLog('[VisitTrailTracker] device id unavailable: $e');
    }
  }

  /// A device-clock instant expressed on the server's clock.
  DateTime _serverTime(DateTime deviceTime) =>
      serverClock?.toServer(deviceTime) ?? deviceTime.toUtc();

  /// A server-clock instant expressed on the device's clock.
  DateTime? _deviceTimeOf(DateTime? serverTime) {
    if (serverTime == null) return null;
    return serverClock?.toDevice(serverTime) ?? serverTime.toUtc();
  }

  Future<void> _guard(String what, Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      appLog('[VisitTrailTracker] $what failed: $e');
    }
  }

  void dispose() {
    _disposed = true;
    _streamEpoch++;
    WidgetsBinding.instance.removeObserver(this);
    connectivity.removeListener(_onConnectivity);
    unawaited(_fallback?.cancel());
    _drainTimer?.cancel();
    _flushTimer?.cancel();
    _dropped.close();
    _pendingCount.dispose();
    _revision.dispose();
    _status.dispose();
  }
}

/// The visit being recorded on this device, persisted so a restarted process
/// knows what it was doing.
class _Marker {
  final int visitId;

  /// `server|uid` of the account that started the recording.
  final String? owner;

  /// Device time from which fixes belong to the visit.
  final DateTime since;
  final double? seedLatitude;
  final double? seedLongitude;

  const _Marker({
    required this.visitId,
    required this.since,
    this.owner,
    this.seedLatitude,
    this.seedLongitude,
  });

  Map<String, dynamic> toJson() => {
        'v': visitId,
        's': since.millisecondsSinceEpoch,
        if (owner != null) 'o': owner,
        if (seedLatitude != null) 'lat': seedLatitude,
        if (seedLongitude != null) 'lng': seedLongitude,
      };

  static _Marker? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final visitId = raw['v'];
    final since = raw['s'];
    if (visitId is! num || since is! num) return null;
    final lat = raw['lat'];
    final lng = raw['lng'];
    final owner = raw['o'];
    return _Marker(
      visitId: visitId.toInt(),
      since: DateTime.fromMillisecondsSinceEpoch(since.toInt(), isUtc: true),
      owner: owner is String ? owner : null,
      seedLatitude: lat is num ? lat.toDouble() : null,
      seedLongitude: lng is num ? lng.toDouble() : null,
    );
  }
}

/// What sending one visit's points came to.
class _FlushOutcome {
  final List<_BufferedPoint> keep;
  final bool landed;
  final int dropped;

  /// The server refused at least one point, or the whole batch.
  final bool refused;

  const _FlushOutcome(this.keep, this.landed, this.dropped, this.refused);
}

/// A buffered fix plus the visit and account it belongs to, and how many
/// times the server has refused the batch carrying it.
class _BufferedPoint {
  final int visitId;
  final String? owner;
  final TrailPoint point;
  final int attempts;

  const _BufferedPoint({
    required this.visitId,
    required this.point,
    this.owner,
    this.attempts = 0,
  });

  /// Identity of the fix itself (not of this attempt count), used to tell the
  /// points a flush sent apart from ones buffered while it was running, and to
  /// never buffer the same fix twice.
  String get key =>
      '$visitId|${point.loggedAt.microsecondsSinceEpoch}|'
      '${point.latitude}|${point.longitude}';

  _BufferedPoint withAttempt() => _BufferedPoint(
        visitId: visitId,
        owner: owner,
        point: point,
        attempts: attempts + 1,
      );

  Map<String, dynamic> toJson() => {
        'v': visitId,
        if (owner != null) 'o': owner,
        'n': attempts,
        'p': point.toJson(),
      };

  static _BufferedPoint? tryFromJson(Map<String, dynamic> j) {
    final visitId = (j['v'] as num?)?.toInt();
    final raw = j['p'];
    if (visitId == null || raw is! Map) return null;
    final point = TrailPoint.tryFromJson(Map<String, dynamic>.from(raw));
    if (point == null) return null;
    final owner = j['o'];
    return _BufferedPoint(
      visitId: visitId,
      owner: owner is String ? owner : null,
      point: point,
      attempts: (j['n'] as num?)?.toInt() ?? 0,
    );
  }
}
