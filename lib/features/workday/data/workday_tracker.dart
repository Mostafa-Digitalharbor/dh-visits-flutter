import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/constants.dart';
import '../../../core/location/location_service.dart';
import '../../../core/location/tracker_plumbing.dart';
import '../../../core/location/workday_location_channel.dart';
import '../../../core/network/connectivity_status.dart';
import '../../../core/network/server_clock.dart';
import '../../../core/storage/session_storage.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/utils/distance.dart';
import '../../visits/data/models/visit_location_log.dart';
import '../../visits/data/visit_trail_tracker.dart';
import 'models/workday_models.dart';
import 'workday_repository.dart';

enum WorkdayPhase {
  /// No signed-in user resolved yet.
  unknown,

  /// The connected server has no work-day store.
  unsupported,
  inactive,
  active,
}

class WorkdayStatus extends Equatable {
  final WorkdayPhase phase;

  /// When the open work day started (server clock, UTC).
  final DateTime? startedAt;

  /// Work-day points recorded on the device and not yet on the server.
  final int pending;

  /// Whether positions are actually being captured for the open work day.
  /// False while active means capture could not be (re)started — typically
  /// location permission was revoked.
  final bool capturing;

  const WorkdayStatus({
    this.phase = WorkdayPhase.unknown,
    this.startedAt,
    this.pending = 0,
    this.capturing = false,
  });

  bool get isActive => phase == WorkdayPhase.active;

  @override
  List<Object?> get props => [phase, startedAt, pending, capturing];
}

/// Records the employee's route for the whole of a work day, and keeps it in
/// sync with the server.
///
/// **Work day vs visit.** A visit trail is the path between one visit's Start
/// and End, stored per visit by `/api/visit/*` ([VisitTrailTracker]). A work
/// day is the envelope around all of them: from "Start work day" to "End work
/// day", *including* the movement between visits. Both are kept: every point
/// of the day belongs to the work day, and a point taken while a visit ran
/// also carries that visit's id — and is handed to [VisitTrailTracker] too, so
/// the visit's own trail keeps coming from the visit API exactly as before.
///
/// **One location source.** On Android, positions come from a foreground
/// service (`WorkdayLocationService`) that keeps capturing with the app in the
/// background, the screen locked, or the Flutter UI gone. It journals each
/// fix to disk natively; this class moves them into its own queue
/// ([drain]). While the day is open [VisitTrailTracker] opens no GPS stream of
/// its own ([TrailFeed]). Elsewhere a foreground position stream stands in.
///
/// **Offline first.** A work day, its start and end, and every fix are
/// persisted before anything is sent. [flushNow] then creates the server
/// session if needed, uploads points oldest first, and completes the session
/// only once none of its points are left — the server refuses a point into a
/// completed session. Client-generated ids make every create idempotent, so a
/// request whose response was lost is never stored twice. `logged_at` is
/// always the fix's own time, read against the server's clock ([ServerClock]).
///
/// **Privacy.** Capture runs only between an explicit Start and End (or until
/// logout). Ending stops the service before anything else happens; a fix that
/// still reaches the journal afterwards is ignored.
class WorkdayTracker
    with WidgetsBindingObserver, TrackerPlumbing
    implements TrailFeed {
  final SharedPreferences prefs;
  final WorkdayRepository repository;
  final SessionStorage sessionStorage;
  final LocationService locationService;
  final ConnectivityStatus connectivity;
  final WorkdayLocationChannel channel;
  @override
  final ServerClock? serverClock;
  @override
  final Future<String?> Function()? deviceId;

  /// Resolved lazily: the visit tracker is built first and points back here.
  final VisitTrailTracker? Function()? visitTracker;

  WorkdayTracker({
    required this.prefs,
    required this.repository,
    required this.sessionStorage,
    required this.locationService,
    required this.connectivity,
    WorkdayLocationChannel? channel,
    this.serverClock,
    this.deviceId,
    this.visitTracker,
  }) : channel = channel ?? const WorkdayLocationChannel() {
    WidgetsBinding.instance.addObserver(this);
    connectivity.addListener(_onConnectivity);
  }

  static const String _daysKey = 'workday_days_v1';
  static const String _queueKey = 'workday_points_v1';
  static const String _seqKey = 'workday_native_seq_v1';
  static const String _supportedKey = 'workday_supported_v1';
  static const String _samplingKey = 'workday_sampling_v1';

  /// The sampling rules the native service was last started with.
  static final String _sampling =
      '${AppConstants.workdayMinDistanceMeters}|'
      '${AppConstants.workdayMinInterval.inMilliseconds}|'
      '${AppConstants.workdayMaxAccuracyMeters}';

  final ValueNotifier<WorkdayStatus> _status = ValueNotifier<WorkdayStatus>(
    const WorkdayStatus(),
  );
  ValueListenable<WorkdayStatus> get status => _status;

  /// Bumped whenever something landed on the server, so an open route screen
  /// can re-read the authoritative route.
  final ValueNotifier<int> _revision = ValueNotifier<int>(0);
  ValueListenable<int> get revision => _revision;

  /// Recorded points the server refused for good. Whoever listens owes the
  /// user an explanation.
  final StreamController<int> _dropped = StreamController<int>.broadcast();
  Stream<int> get onPointsDropped => _dropped.stream;

  int? _userId;
  bool _unsupported = false;
  bool _capturing = false;

  /// True while a restored day waits for the user's agreement to the
  /// background-location disclosure, and after they declined it: no app resume
  /// may start capture meanwhile. Cleared when capture starts legitimately
  /// (Start, or Retry after agreeing) and on sign-out.
  bool _consentHeld = false;
  bool _disposed = false;
  @override
  String get logTag => '[WorkdayTracker]';
  Timer? _drainTimer;
  Timer? _flushTimer;
  Future<void>? _draining;
  Future<void>? _inFlight;

  // Foreground-stream stand-in where there is no native service.
  StreamSubscription<Position>? _fallback;
  Position? _lastFallback;
  int? _fallbackVisitId;

  // ---------------------------------------------------------------------------
  // TrailFeed
  // ---------------------------------------------------------------------------

  @override
  bool get isActive => _capturing && _activeDay != null;

  @override
  void activeVisitChanged(int? visitId) {
    _fallbackVisitId = visitId;
    if (!channel.isAvailable || _activeDay == null) return;
    unawaited(
      guard('set visit', () => channel.setVisit(visitId, DateTime.now())),
    );
  }

  /// Moves every fix the native service journalled into the upload queue.
  /// Waits for a drain already running and then drains again, so a caller
  /// that needs "everything up to now" (ending a visit) gets it.
  @override
  Future<void> drain() async {
    while (_draining != null) {
      await _draining;
    }
    final run = _drain();
    _draining = run;
    try {
      await run;
    } finally {
      _draining = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Restores the work day after login or an app restart: resumes capture for
  /// a day still open on this device, adopts one still open on the server
  /// (never creating a second), and uploads whatever is waiting.
  ///
  /// [beforeCapture] runs right before capture resumes; returning false keeps
  /// the day open but not recording (the work-day bar then offers Retry). The
  /// shell uses it to show the background-location disclosure on an install
  /// that has not shown it yet, e.g. a day started on another device.
  Future<void> restore({
    required String notificationTitle,
    required String notificationText,
    Future<bool> Function()? beforeCapture,
  }) async {
    // Set before the first await: an app resume while this runs (a permission
    // prompt closing) must not start capture ahead of the user's answer.
    _consentHeld = beforeCapture != null;
    final user = await _currentUser();
    if (user == null) return;
    _userId = user.uid;
    _unsupported = false;
    await resolveDeviceId();

    final foreign = _readDays().where((d) => d.userId != user.uid).toList();
    if (foreign.isNotEmpty) {
      await _discard(
        foreign,
        reason: 'recorded under another account',
        notify: false,
      );
    }

    var day = _activeDay;
    if (day != null && day.serverId != null) {
      try {
        final server = await repository.readSession(day.serverId!);
        if (server == null || !server.isActive) {
          await _stopCapture();
          await _discard([
            day,
          ], reason: 'the work day was closed on the server');
          day = null;
        }
      } on ApiException catch (e) {
        if (WorkdayRepository.isMissingModel(e)) return _markUnsupported();
        appLog(
          '[WorkdayTracker] could not verify the open work day: ${e.code}',
        );
      }
    }

    if (day == null) {
      // Nothing open here: native capture must not be running either.
      if (channel.isAvailable) {
        await guard('status', () async {
          final st = await channel.status();
          if (st.active || st.running) await channel.stop();
        });
      }
      try {
        final supported = await _checkSupport();
        if (supported == false) return _markUnsupported();
        final server = await repository.activeSession(user.uid);
        if (server != null) {
          day = _DayRecord.fromServer(server, userId: user.uid);
          await _saveDay(day);
          appLog(
            '[WorkdayTracker] resumed work day ${server.id} open on the server',
          );
        }
      } on ApiException catch (e) {
        if (WorkdayRepository.isMissingModel(e)) return _markUnsupported();
        appLog(
          '[WorkdayTracker] could not look up an open work day: ${e.code}',
        );
      }
    }

    if (day != null) {
      day
        ..title = notificationTitle
        ..text = notificationText;
      await _saveDay(day);
      // Disclosure before any permission prompt, as on Start. Declining keeps
      // the day open but not recording (the bar offers Retry), and the hold
      // stops app resumes from starting capture meanwhile.
      if (beforeCapture != null && !await beforeCapture()) {
        await _stopCapture();
        _capturing = false;
        _consentHeld = true;
        appLog(
          '[WorkdayTracker] disclosure not accepted on this install; capture paused',
        );
      } else {
        _consentHeld = false;
        if (!await locationService.ensurePermission()) {
          _capturing = false;
          appLog(
            '[WorkdayTracker] location permission missing; capture paused',
          );
        } else {
          await _startCapture(day);
        }
      }
    } else {
      _consentHeld = false;
    }
    if (_readDays().isNotEmpty) _startTimers();
    _publish();
    await drain();
    unawaited(flushNow(probe: true));
  }

  /// Opens a work day at the given position. A no-op while one is already
  /// open; adopts the server's open day instead of creating a duplicate.
  ///
  /// Throws [ApiException] with [ApiErrorCode.notSupported] when the server has
  /// no work-day store.
  Future<void> startDay({
    required double latitude,
    required double longitude,
    required String notificationTitle,
    required String notificationText,
  }) async {
    final user = await _currentUser();
    if (user == null) throw ApiException.unauthorized();
    _userId = user.uid;
    await resolveDeviceId();

    final open = _activeDay;
    if (open != null) {
      if (!_capturing) await _startCapture(open);
      return;
    }

    final supported = await _checkSupport();
    if (supported == false) {
      await _markUnsupported();
      throw ApiException(code: ApiErrorCode.notSupported);
    }
    _unsupported = false;

    WorkSession? server;
    try {
      server = await repository.activeSession(user.uid);
    } on ApiException catch (e) {
      // Offline: start locally; the session is created when the network is back.
      if (!e.isRetryable) rethrow;
    }

    final _DayRecord day;
    if (server != null) {
      day = _DayRecord.fromServer(server, userId: user.uid);
    } else {
      final now = serverNow();
      day = _DayRecord(
        uid: _newUid(),
        userId: user.uid,
        employeeId: user.employeeId,
        startedAt: now,
        startLatitude: latitude,
        startLongitude: longitude,
      );
    }
    day
      ..title = notificationTitle
      ..text = notificationText;
    await _saveDay(day);
    if (server == null) {
      await _enqueue(
        WorkdayPoint(
          uid: '${day.uid}-start',
          sessionUid: day.uid,
          source: WorkdayPointSource.start,
          point: TrailPoint(
            latitude: latitude,
            longitude: longitude,
            loggedAt: day.startedAt,
            deviceId: deviceIdValue,
          ),
        ),
      );
    }
    appLog('[WorkdayTracker] work day ${day.uid} started');
    await _startCapture(day);
    _publish();
    unawaited(flushNow());
  }

  /// Closes the open work day: stops capture first, keeps every fix taken up
  /// to now, records the end position, then uploads and completes the session.
  ///
  /// Returns true when the server has the day completed, false when that is
  /// still queued (offline) — it completes on a later sync.
  Future<bool> endDay({double? latitude, double? longitude}) async {
    final day = _activeDay;
    if (day == null) return true;
    await _stopCapture();
    await drain();

    final now = serverNow();
    day
      ..state = _DayRecord.ending
      ..endedAt = now
      ..endLatitude = latitude
      ..endLongitude = longitude;
    await _saveDay(day);
    if (latitude != null && longitude != null) {
      await _enqueue(
        WorkdayPoint(
          uid: '${day.uid}-end',
          sessionUid: day.uid,
          visitId: visitTracker?.call()?.activeVisitId,
          source: WorkdayPointSource.end,
          point: TrailPoint(
            latitude: latitude,
            longitude: longitude,
            loggedAt: now,
            deviceId: deviceIdValue,
          ),
        ),
      );
    }
    appLog('[WorkdayTracker] work day ${day.uid} ended');
    _publish();
    await flushNow();
    return !_readDays().any((d) => d.uid == day.uid);
  }

  /// Signing out: capture stops (nobody may be tracked while signed out) and
  /// what was recorded is pushed while the session is still valid. The work
  /// day itself stays open on the server and resumes on the next sign-in.
  Future<void> suspend() async {
    await _stopCapture();
    await drain();
    await flushNow();
    _drainTimer?.cancel();
    _drainTimer = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    _userId = null;
    _consentHeld = false;
    _publish();
  }

  @override
  // ignore: avoid_renaming_method_parameters
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    switch (lifecycle) {
      case AppLifecycleState.resumed:
        final day = _activeDay;
        if (day != null) {
          if (channel.isAvailable) {
            unawaited(_ensureNativeRunning(day));
          } else if (_capturing) {
            _subscribeFallback();
          }
        }
        if (_readDays().isNotEmpty) {
          unawaited(drain().then((_) => flushNow(probe: true)));
        }
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        if (!channel.isAvailable) {
          _fallback?.cancel();
          _fallback = null;
        }
        if (_readDays().isNotEmpty) {
          unawaited(drain().then((_) => flushNow()));
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _onConnectivity() {
    if (connectivity.isOnline && _readDays().isNotEmpty) unawaited(flushNow());
  }

  // ---------------------------------------------------------------------------
  // Capture
  // ---------------------------------------------------------------------------

  Future<void> _startCapture(_DayRecord day) async {
    // Every caller has the user's agreement (Start after the disclosure, or a
    // restore that passed it); the resume path checks [_consentHeld] first.
    _consentHeld = false;
    if (channel.isAvailable) {
      try {
        final st = await channel.status();
        // Also (re)started when the sampling rules changed since capture was
        // configured — an app update in the middle of a day — so a service the
        // system kept alive takes the new ones on.
        final samplingChanged = prefs.getString(_samplingKey) != _sampling;
        if (!(st.active && st.running) || samplingChanged) {
          await channel.start(
            sessionUid: day.uid,
            minDistanceMeters: AppConstants.workdayMinDistanceMeters,
            minInterval: AppConstants.workdayMinInterval,
            maxAccuracyMeters: AppConstants.workdayMaxAccuracyMeters,
            startedAt: DateTime.now(),
            title: day.title,
            text: day.text,
            visitId: visitTracker?.call()?.activeVisitId,
            visitSince: DateTime.now(),
            seedLatitude: day.startLatitude,
            seedLongitude: day.startLongitude,
          );
          await prefs.setString(_samplingKey, _sampling);
        }
        _capturing = true;
      } catch (e) {
        appLog('[WorkdayTracker] could not start location capture: $e');
        _capturing = false;
      }
    } else {
      _capturing = true;
      _fallbackVisitId = visitTracker?.call()?.activeVisitId;
      if (isForeground) _subscribeFallback();
    }
    _startTimers();
    visitTracker?.call()?.feedChanged();
    _publish();
  }

  /// The system may have killed the service with the process; bring it back
  /// when the app is opened again.
  Future<void> _ensureNativeRunning(_DayRecord day) async {
    // Waiting for, or refused, the disclosure on this install: nothing starts.
    if (_consentHeld) return;
    await guard('ensure capture', () async {
      final st = await channel.status();
      if (st.active && st.running) return;
      if (!await locationService.ensurePermission()) {
        _capturing = false;
        _publish();
        return;
      }
      await _startCapture(day);
    });
  }

  Future<void> _stopCapture() async {
    _capturing = false;
    await _fallback?.cancel();
    _fallback = null;
    _lastFallback = null;
    if (channel.isAvailable) {
      await guard('stop capture', channel.stop);
    }
    visitTracker?.call()?.feedChanged();
  }

  void _subscribeFallback() {
    if (_fallback != null) return;
    _fallback = locationService
        .watch(distanceFilter: AppConstants.workdayMinDistanceMeters.round())
        .listen(
          _onFallbackPosition,
          onError: (Object e) =>
              appLog('[WorkdayTracker] position stream error: $e'),
          cancelOnError: false,
        );
  }

  void _onFallbackPosition(Position pos) {
    final day = _activeDay;
    if (day == null || !_capturing) return;
    if (pos.accuracy > AppConstants.workdayMaxAccuracyMeters) return;
    final last = _lastFallback;
    if (last != null) {
      // The native service's rules: newer than the last fix, really moved,
      // and not faster than the sampling interval unless covering ground.
      if (!pos.timestamp.isAfter(last.timestamp)) return;
      final moved = haversineMeters(
        last.latitude,
        last.longitude,
        pos.latitude,
        pos.longitude,
      );
      final elapsed = pos.timestamp.difference(last.timestamp);
      if (moved < AppConstants.workdayMinDistanceMeters) return;
      if (elapsed < AppConstants.workdayMinInterval &&
          moved < AppConstants.workdayBurstDistanceMeters) {
        return;
      }
    }
    _lastFallback = pos;
    final visitId = _fallbackVisitId;
    final point = TrailPoint(
      latitude: pos.latitude,
      longitude: pos.longitude,
      loggedAt: serverTimeOf(pos.timestamp),
      accuracy: pos.accuracy > 0 ? pos.accuracy : null,
      altitude: pos.altitude,
      speed: pos.speed >= 0 ? pos.speed : null,
      heading: pos.heading >= 0 ? pos.heading : null,
      deviceId: deviceIdValue,
    );
    unawaited(() async {
      await _enqueue(
        WorkdayPoint(
          uid: '${day.uid}-f${pos.timestamp.microsecondsSinceEpoch}',
          sessionUid: day.uid,
          visitId: visitId,
          source: WorkdayPointSource.track,
          point: point,
        ),
      );
      if (visitId != null) await visitTracker?.call()?.ingest(visitId, point);
      _publish();
    }());
  }

  static const String _installKey = 'workday_install_v1';

  /// Random per install, cleared with the app's data. Native fix uids carry
  /// it because the capture journal's sequence restarts at 1 after a reinstall
  /// or a data clear: a plain `<day>-<seq>` would then repeat a uid the server
  /// already holds for the same day, and the backend's unique index would
  /// discard the new fix as a duplicate.
  Future<String> _installToken() async {
    final saved = prefs.getString(_installKey);
    if (saved != null) return saved;
    final r = Random.secure();
    final token = [
      for (var i = 0; i < 4; i++)
        r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    await prefs.setString(_installKey, token);
    return token;
  }

  Future<void> _drain() async {
    if (!channel.isAvailable) return;
    final List<CapturedFix> fixes;
    try {
      fixes = await channel.read(max: AppConstants.trailMaxBatchSize * 10);
    } catch (e) {
      appLog('[WorkdayTracker] capture journal unreadable: $e');
      return;
    }
    if (fixes.isEmpty) return;

    final install = await _installToken();
    final lastSeq = prefs.getInt(_seqKey) ?? 0;
    final days = _readDays();
    final taken = <WorkdayPoint>[];
    final forwards = <(int, TrailPoint)>[];
    var maxSeq = lastSeq;
    for (final f in fixes) {
      if (f.seq > maxSeq) maxSeq = f.seq;
      if (f.seq <= lastSeq) continue;
      _DayRecord? day;
      for (final d in days) {
        if (d.uid == f.sessionUid) day = d;
      }
      if (day == null) {
        appLog(
          '[WorkdayTracker] fix #${f.seq} belongs to no open work day; ignored',
        );
        continue;
      }
      final at = serverTimeOf(f.deviceTime);
      final endedAt = day.endedAt;
      if (endedAt != null && at.isAfter(endedAt)) continue;
      final point = TrailPoint(
        latitude: f.latitude,
        longitude: f.longitude,
        // The fix's own time, only re-read against the server's clock.
        loggedAt: at,
        accuracy: f.accuracy,
        altitude: f.altitude,
        speed: f.speed,
        heading: f.heading,
        deviceId: deviceIdValue,
      );
      taken.add(
        WorkdayPoint(
          uid: '${day.uid}-$install-${f.seq}',
          sessionUid: day.uid,
          visitId: f.visitId,
          source: WorkdayPointSource.track,
          point: point,
        ),
      );
      if (f.visitId != null) forwards.add((f.visitId!, point));
    }

    // Visit trail first (its buffer ignores a fix it already holds), then the
    // work-day queue, then the acknowledgement: a crash anywhere in between
    // replays the drain instead of losing a fix.
    final vt = visitTracker?.call();
    for (final (visitId, point) in forwards) {
      await vt?.ingest(visitId, point);
    }
    if (taken.isNotEmpty) {
      final queue = _readQueue();
      final known = {for (final p in queue) p.uid};
      queue.addAll(taken.where((p) => known.add(p.uid)));
      await _writeQueue(queue);
      appLog('[WorkdayTracker] took over ${taken.length} captured fix(es)');
    }
    await prefs.setInt(_seqKey, maxSeq);
    await guard('ack journal', () => channel.ack(maxSeq));
    if (forwards.isNotEmpty && vt != null) unawaited(vt.flushNow());
    _publish();
    if (_readQueue().length >= AppConstants.trailFlushBatchSize) {
      unawaited(flushNow());
    }
  }

  // ---------------------------------------------------------------------------
  // Sync
  // ---------------------------------------------------------------------------

  /// Pushes every waiting work day to the server, oldest first. Waits for a
  /// sync already running, then runs again. Never throws.
  ///
  /// [probe] sends even while [ConnectivityStatus] reads offline — the same
  /// deadlock breaker as the visit trail's (that flag only flips back after a
  /// request succeeds).
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
    var dropped = 0;
    var landed = false;
    try {
      final userId = _userId;
      if (userId == null) return;
      final days = _readDays().where((d) => d.userId == userId).toList()
        ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
      if (days.isEmpty) return;
      if (!connectivity.isOnline && !probe) return;

      for (final day in days) {
        if (day.serverId == null) {
          // Look it up first: a create whose response never arrived may well
          // have happened.
          final existing = await repository.sessionByClientUid(day.uid);
          day.serverId =
              existing?.id ??
              await repository.createSession(
                clientUid: day.uid,
                employeeId: day.employeeId,
                startedAt: day.startedAt,
                latitude: day.startLatitude,
                longitude: day.startLongitude,
                deviceId: deviceIdValue,
              );
          await _saveDay(day);
          landed = true;
          appLog(
            '[WorkdayTracker] work day ${day.uid} is server session ${day.serverId}',
          );
        }
        final result = await _flushPoints(day);
        dropped += result.dropped;
        landed = landed || result.landed;
        if (result.interrupted) break;
        if (day.state == _DayRecord.ending &&
            !_readQueue().any((p) => p.sessionUid == day.uid)) {
          await _complete(day);
          landed = true;
        }
      }
    } on ApiException catch (e) {
      if (WorkdayRepository.isMissingModel(e)) {
        await _markUnsupported();
      } else {
        appLog(
          '[WorkdayTracker] sync paused: ${e.code} ${e.serverMessage ?? ''}',
        );
      }
    } catch (e) {
      appLog('[WorkdayTracker] sync failed: $e');
    } finally {
      if (dropped > 0 && !_disposed) _dropped.add(dropped);
      if (landed && !_disposed) _revision.value++;
      _publish();
      if (_readDays().isEmpty && _userId != null) _stopTimers();
    }
  }

  Future<({bool landed, int dropped, bool interrupted})> _flushPoints(
    _DayRecord day,
  ) async {
    int rank(WorkdayPoint p) => p.source.index;
    final sent = _readQueue().where((p) => p.sessionUid == day.uid).toList()
      ..sort((a, b) {
        final byTime = a.point.loggedAt.compareTo(b.point.loggedAt);
        return byTime != 0 ? byTime : rank(a).compareTo(rank(b));
      });
    if (sent.isEmpty) return (landed: false, dropped: 0, interrupted: false);

    final sessionId = day.serverId!;
    final keep = <WorkdayPoint>[];
    var remaining = sent;
    var landed = false;
    var dropped = 0;
    var interrupted = false;

    while (remaining.isNotEmpty) {
      var batch = remaining.take(AppConstants.trailMaxBatchSize).toList();
      final rest = remaining.skip(batch.length).toList();
      try {
        final unsure = [
          for (final p in batch)
            if (p.maybeSent) p.uid,
        ];
        if (unsure.isNotEmpty) {
          final already = await repository.existingPointUids(unsure);
          if (already.isNotEmpty) {
            landed = true;
            batch = [
              for (final p in batch)
                if (!already.contains(p.uid)) p,
            ];
          }
        }
        if (batch.isNotEmpty) {
          await repository.createPoints(
            sessionId,
            employeeId: day.employeeId,
            points: batch,
          );
          landed = true;
        }
        remaining = rest;
      } on ApiException catch (e) {
        if (e.isRetryable) {
          // Unknown whether it was stored: check before resending.
          keep
            ..addAll([for (final p in batch) p.markMaybeSent()])
            ..addAll(rest);
          interrupted = true;
          break;
        }
        // One create is all-or-nothing: find the point(s) at fault one by one
        // so a single bad fix never holds back the rest of the day.
        for (final p in batch) {
          try {
            await repository.createPoints(
              sessionId,
              employeeId: day.employeeId,
              points: [p],
            );
            landed = true;
          } on ApiException catch (single) {
            if (single.isRetryable) {
              keep.add(p.markMaybeSent());
            } else if (single.code == ApiErrorCode.permissionDenied ||
                p.attempts + 1 >= AppConstants.trailMaxFlushAttempts) {
              // Refused by the access rules (e.g. the day was already closed)
              // or refused again and again: it will never be accepted.
              dropped++;
              appLog(
                '[WorkdayTracker] point ${p.uid} refused: '
                '${single.serverMessage ?? single.code}',
              );
            } else {
              keep.add(p.withAttempt());
            }
          }
        }
        remaining = rest;
      }
    }

    // Points queued while the requests were in flight are only on disk: keep
    // them. Read and written with no await in between.
    final sentUids = {for (final p in sent) p.uid};
    final current = _readQueue();
    await _writeQueue([
      ...current.where((p) => !sentUids.contains(p.uid)),
      ...keep,
    ]);
    return (landed: landed, dropped: dropped, interrupted: interrupted);
  }

  Future<void> _complete(_DayRecord day) async {
    try {
      await repository.completeSession(
        day.serverId!,
        endedAt: day.endedAt ?? serverNow(),
        latitude: day.endLatitude,
        longitude: day.endLongitude,
      );
    } on ApiException catch (e) {
      if (e.isRetryable) rethrow;
      // A completed session can't be written again: refused because it
      // already is completed (e.g. a retried request) counts as done.
      final server = await repository.readSession(day.serverId!);
      if (server != null && server.isActive) rethrow;
    }
    await _removeDays({day.uid});
    appLog('[WorkdayTracker] work day ${day.uid} completed on the server');
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<({int uid, int? employeeId})?> _currentUser() async {
    try {
      final user = await sessionStorage.getUser();
      final uid = (user?['uid'] as num?)?.toInt();
      if (uid == null) return null;
      return (uid: uid, employeeId: (user?['employee_id'] as num?)?.toInt());
    } catch (_) {
      return null;
    }
  }

  /// True / false once known; null when it could not be checked (offline).
  Future<bool?> _checkSupport() async {
    if (prefs.getBool(_supportedKey) == true) return true;
    try {
      final supported = await repository.isSupported();
      if (supported) await prefs.setBool(_supportedKey, true);
      return supported;
    } on ApiException catch (e) {
      if (e.isRetryable) return null;
      rethrow;
    }
  }

  Future<void> _markUnsupported() async {
    _unsupported = true;
    await prefs.remove(_supportedKey);
    await _stopCapture();
    final days = _readDays();
    if (days.isNotEmpty) {
      await _discard(
        days,
        reason: 'the server has no work-day store',
        notify: false,
      );
    }
    _stopTimers();
    _publish();
  }

  void _startTimers() {
    _drainTimer ??= Timer.periodic(
      AppConstants.workdayDrainInterval,
      (_) => unawaited(drain()),
    );
    _flushTimer ??= Timer.periodic(
      AppConstants.workdayFlushInterval,
      (_) => unawaited(flushNow(probe: true)),
    );
  }

  void _stopTimers() {
    _drainTimer?.cancel();
    _drainTimer = null;
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  String _newUid() {
    final r = Random.secure();
    final hex = [
      for (var i = 0; i < 6; i++)
        r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    return 'wd-${DateTime.now().toUtc().millisecondsSinceEpoch}-$hex';
  }

  void _publish() {
    if (_disposed) return;
    final day = _activeDay;
    _status.value = WorkdayStatus(
      phase: _unsupported
          ? WorkdayPhase.unsupported
          : _userId == null
          ? WorkdayPhase.unknown
          : day != null
          ? WorkdayPhase.active
          : WorkdayPhase.inactive,
      startedAt: day?.startedAt,
      pending: _readQueue().length,
      capturing: _capturing && day != null,
    );
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  _DayRecord? get _activeDay {
    final uid = _userId;
    if (uid == null) return null;
    for (final d in _readDays()) {
      if (d.userId == uid && d.state == _DayRecord.active) return d;
    }
    return null;
  }

  List<_DayRecord> _readDays() => [
    for (final m in decodeStoredJsonList(() => prefs.getString(_daysKey)))
      ?_DayRecord.tryFromJson(m),
  ];

  Future<void> _writeDays(List<_DayRecord> days) async {
    if (days.isEmpty) {
      await prefs.remove(_daysKey);
    } else {
      await prefs.setString(
        _daysKey,
        jsonEncode([for (final d in days) d.toJson()]),
      );
    }
  }

  /// Upserts [day], never forgetting a server id another path already learnt.
  Future<void> _saveDay(_DayRecord day) async {
    final days = _readDays();
    final i = days.indexWhere((d) => d.uid == day.uid);
    if (i >= 0) {
      day.serverId ??= days[i].serverId;
      days[i] = day;
    } else {
      days.add(day);
    }
    await _writeDays(days);
  }

  Future<void> _removeDays(Set<String> uids) async {
    final days = _readDays()..removeWhere((d) => uids.contains(d.uid));
    await _writeDays(days);
  }

  /// Forgets [days] and their queued points (they can never be uploaded).
  Future<void> _discard(
    List<_DayRecord> days, {
    required String reason,
    bool notify = true,
  }) async {
    final uids = {for (final d in days) d.uid};
    final queue = _readQueue();
    final lost = queue.where((p) => uids.contains(p.sessionUid)).length;
    await _writeQueue(
      queue.where((p) => !uids.contains(p.sessionUid)).toList(),
    );
    await _removeDays(uids);
    appLog(
      '[WorkdayTracker] discarded ${days.length} work day(s) and $lost '
      'point(s): $reason',
    );
    if (notify && lost > 0 && !_disposed) _dropped.add(lost);
  }

  List<WorkdayPoint> _readQueue() => [
    for (final m in decodeStoredJsonList(() => prefs.getString(_queueKey)))
      ?WorkdayPoint.tryFromJson(m),
  ];

  Future<void> _writeQueue(List<WorkdayPoint> points) async {
    if (points.length > AppConstants.workdayMaxBufferedPoints) {
      final overflow = points.length - AppConstants.workdayMaxBufferedPoints;
      points.removeRange(0, overflow);
      appLog('[WorkdayTracker] queue full; dropped $overflow oldest point(s)');
      if (!_disposed) _dropped.add(overflow);
    }
    if (points.isEmpty) {
      await prefs.remove(_queueKey);
    } else {
      await prefs.setString(
        _queueKey,
        jsonEncode([for (final p in points) p.toJson()]),
      );
    }
  }

  Future<void> _enqueue(WorkdayPoint point) async {
    final queue = _readQueue();
    if (queue.any((p) => p.uid == point.uid)) return;
    queue.add(point);
    await _writeQueue(queue);
  }

  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    connectivity.removeListener(_onConnectivity);
    _stopTimers();
    _fallback?.cancel();
    _dropped.close();
    _status.dispose();
    _revision.dispose();
  }
}

/// One work day as this device knows it.
class _DayRecord {
  static const String active = 'active';

  /// Ended here; its points and completion may still be waiting to upload.
  static const String ending = 'ending';

  final String uid;
  final int userId;
  final int? employeeId;
  final DateTime startedAt;
  final double? startLatitude;
  final double? startLongitude;
  int? serverId;
  String state;
  DateTime? endedAt;
  double? endLatitude;
  double? endLongitude;
  String title;
  String text;

  _DayRecord({
    required this.uid,
    required this.userId,
    required this.startedAt,
    this.employeeId,
    this.startLatitude,
    this.startLongitude,
    this.serverId,
    this.state = active,
    this.endedAt,
    this.endLatitude,
    this.endLongitude,
    this.title = '',
    this.text = '',
  });

  factory _DayRecord.fromServer(WorkSession s, {required int userId}) =>
      _DayRecord(
        uid: s.clientUid ?? 'srv-${s.id}',
        userId: userId,
        employeeId: s.employeeId,
        startedAt: s.startedAt,
        startLatitude: s.startLatitude,
        startLongitude: s.startLongitude,
        serverId: s.id,
      );

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'user': userId,
    if (employeeId != null) 'emp': employeeId,
    'start': startedAt.toUtc().toIso8601String(),
    if (startLatitude != null) 'slat': startLatitude,
    if (startLongitude != null) 'slng': startLongitude,
    if (serverId != null) 'sid': serverId,
    'state': state,
    if (endedAt != null) 'end': endedAt!.toUtc().toIso8601String(),
    if (endLatitude != null) 'elat': endLatitude,
    if (endLongitude != null) 'elng': endLongitude,
    'title': title,
    'text': text,
  };

  static _DayRecord? tryFromJson(Map<String, dynamic> j) {
    final uid = j['uid'];
    final user = j['user'];
    final start = DateTime.tryParse(j['start']?.toString() ?? '');
    if (uid is! String || user is! num || start == null) return null;
    double? d(Object? v) => v is num ? v.toDouble() : null;
    // Type-checked rather than cast: a corrupt row (a string where a number
    // belongs, after a partial write) must return null, not throw. It used to
    // throw, and the caller's only recourse was to discard *every* stored day
    // — which silently ended an active work day's tracking.
    int? i(Object? v) => v is num ? v.toInt() : null;
    return _DayRecord(
      uid: uid,
      userId: user.toInt(),
      employeeId: i(j['emp']),
      startedAt: start.toUtc(),
      startLatitude: d(j['slat']),
      startLongitude: d(j['slng']),
      serverId: i(j['sid']),
      state: j['state'] == ending ? ending : active,
      endedAt: DateTime.tryParse(j['end']?.toString() ?? '')?.toUtc(),
      endLatitude: d(j['elat']),
      endLongitude: d(j['elng']),
      title: j['title']?.toString() ?? '',
      text: j['text']?.toString() ?? '',
    );
  }
}
