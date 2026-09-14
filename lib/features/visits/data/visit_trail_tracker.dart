import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/constants.dart';
import '../../../core/location/location_service.dart';
import '../../../core/network/connectivity_status.dart';
import '../../../core/network/pending_actions_queue.dart';
import '../../../core/network/server_clock.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/utils/distance.dart';
import 'models/visit_location_log.dart';
import 'visits_repository.dart';

/// A location source outside [VisitTrailTracker] that takes over sampling
/// while it is active — the work-day capture. The tracker then opens no GPS
/// stream of its own and receives the running visit's fixes via
/// [VisitTrailTracker.ingest] instead.
abstract class TrailFeed {
  /// True while the feed is capturing; the tracker's own stream stays closed.
  bool get isActive;

  /// Tells the feed which visit is running (null: none), so the fixes it takes
  /// from now on are attributed to it.
  void activeVisitChanged(int? visitId);

  /// Delivers every fix captured but not yet handed over.
  Future<void> drain();
}

/// Collects the GPS trail of the visit that is currently running and pushes it
/// to the server in batches.
///
/// The shape of the thing:
///
/// - **One visit at a time.** A rep can only be on one visit at once, and the
///   server refuses a point for a visit that isn't `in_progress` anyway.
/// - **Buffer first, send second.** Every accepted fix lands in a
///   SharedPreferences-backed buffer before anything is sent, so a fix survives
///   the app being killed mid-visit. The buffer is keyed by visit id, so points
///   taken in a dead zone still flush correctly after the visit ends — the
///   server accepts a late upload as long as the fix's `logged_at` falls inside
///   the start–end window.
/// - **Its own GPS stream is foreground only.** Outside a work day the
///   subscription is torn down the moment the app leaves the foreground and
///   restored on resume. During an active work day it opens no stream at all:
///   the work-day capture ([feed]) is the single location source, and hands
///   this tracker the fixes taken while the visit ran through [ingest] —
///   including those taken in the background — so two GPS streams never run
///   side by side.
///
/// It is deliberately *not* a bloc: nothing renders it directly. The trail UI
/// reads the server's copy through `VisitTrailCubit`; this class only feeds it.
/// [pendingCount] and [revision] are exposed so a screen can show "3 fixes
/// waiting to upload" and refresh itself after a flush lands.
class VisitTrailTracker with WidgetsBindingObserver {
  final SharedPreferences prefs;
  final VisitsRepository repository;
  final LocationService locationService;
  final ConnectivityStatus connectivity;

  /// Consulted before a flush: while a Start for this visit is still sitting in
  /// the offline queue, the server has no `in_progress` visit to attach points
  /// to and would refuse the whole batch. See [_flush].
  final PendingActionsQueue Function()? pendingActions;

  /// Re-expresses each fix's device-clock timestamp on the server's clock, so
  /// `logged_at` is comparable with the `start_datetime`/`end_datetime` the
  /// server stamps. See [ServerClock] for the failure this prevents. Null (in
  /// tests) sends the device time unchanged.
  final ServerClock? serverClock;

  /// Stable per-install id sent as each point's `device_id`, the same one the
  /// FCM registration uses, so a manager can tell which handset recorded a
  /// stretch of route.
  final Future<String?> Function()? deviceId;

  /// The work-day capture, when one is wired in. Assigned after construction:
  /// the work-day tracker is built on top of this one.
  TrailFeed? feed;

  VisitTrailTracker({
    required this.prefs,
    required this.repository,
    required this.locationService,
    required this.connectivity,
    this.pendingActions,
    this.serverClock,
    this.deviceId,
  }) {
    WidgetsBinding.instance.addObserver(this);
    _pendingCount.value = _readBuffer().length;
    _connectivityListener = () {
      if (connectivity.isOnline) unawaited(flushNow());
    };
    connectivity.addListener(_connectivityListener!);
  }

  static const String _bufferKey = 'visit_trail_buffer_v1';
  static const String _activeKey = 'visit_trail_active_visit_v1';

  StreamSubscription<Position>? _positions;
  Timer? _flushTimer;
  VoidCallback? _connectivityListener;

  /// The flush currently running. [flushNow] waits on it instead of returning
  /// early — see there.
  Future<void>? _inFlight;

  /// The visit being tracked, or null when idle.
  int? _visitId;
  int? get activeVisitId => _visitId;
  bool get isTracking => _visitId != null;

  /// Device time at which sampling began for [_visitId]. A fix stamped earlier
  /// is a cached position the OS replayed when the stream opened — see
  /// [_onPosition].
  DateTime? _trackingSince;

  String? _deviceIdValue;

  /// The last fix we *kept*, used to reject points that haven't moved far
  /// enough to be worth a vertex.
  Position? _lastKept;

  /// Fixes captured but not yet accepted by the server.
  final ValueNotifier<int> _pendingCount = ValueNotifier<int>(0);
  ValueListenable<int> get pendingCount => _pendingCount;

  /// Bumped every time a flush actually lands points on the server, so an open
  /// trail screen can refetch instead of polling blindly.
  final ValueNotifier<int> _revision = ValueNotifier<int>(0);
  ValueListenable<int> get revision => _revision;

  /// Fires when the server permanently refused buffered fixes (a point outside
  /// the visit's start–end window, say). They are gone from the buffer by the
  /// time this fires: whoever listens owes the user an explanation, exactly as
  /// with [PendingActionsQueue.onDropped].
  final StreamController<int> _dropped = StreamController<int>.broadcast();
  Stream<int> get onPointsDropped => _dropped.stream;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Begins tracking [visitId]. Safe to call again for the visit already being
  /// tracked (a no-op), which is what makes it usable straight from the Start
  /// action *and* from the app-resume path without coordinating the two.
  Future<void> start(int visitId) async {
    if (_visitId == visitId &&
        (_positions != null || (feed?.isActive ?? false))) {
      return;
    }
    if (_visitId != null && _visitId != visitId) {
      // Switching visits: get whatever the old one collected off the device
      // before its subscription goes away. Points are buffered against the id
      // they were taken for, so nothing of the old visit can leak into this one.
      await stop();
    }
    _visitId = visitId;
    _trackingSince = DateTime.now();
    await prefs.setInt(_activeKey, visitId);
    feed?.activeVisitChanged(visitId);
    _lastKept = null;
    await _resolveDeviceId();
    await _subscribe();
    _startFlushTimer();
    // Flush straight away: a previous run may have left points buffered.
    unawaited(flushNow());
  }

  /// Restores tracking after an app restart, but only if the visit that was
  /// being tracked is still the one running.
  ///
  /// Called from the resume path with the server's current `in_progress` visit.
  /// Passing null (nothing is running) clears the stored marker and flushes
  /// whatever was left behind, which is how a visit ended on another device
  /// still gets its dead-zone fixes uploaded.
  Future<void> resume(int? runningVisitId) async {
    final stored = prefs.getInt(_activeKey);
    if (runningVisitId == null) {
      if (stored != null) await prefs.remove(_activeKey);
      _visitId = null;
      feed?.activeVisitChanged(null);
      await flushNow();
      return;
    }
    await start(runningVisitId);
  }

  /// Stops collecting. [flush] is on by default so ending a visit pushes the
  /// tail of the path immediately rather than leaving it for the next timer.
  Future<void> stop({bool flush = true}) async {
    await _positions?.cancel();
    _positions = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    _visitId = null;
    _trackingSince = null;
    _lastKept = null;
    await prefs.remove(_activeKey);
    feed?.activeVisitChanged(null);
    // Under a work day the fixes are captured outside this class: pull in the
    // ones not handed over yet, so End's flush carries the tail of the route.
    if (feed?.isActive ?? false) await feed!.drain();
    if (flush) await flushNow();
  }

  /// Re-evaluates who samples after the work-day capture started or stopped:
  /// closes this tracker's own stream when the feed took over, and reopens it
  /// (foreground only) for a visit still running after the feed went away.
  void feedChanged() {
    if (feed?.isActive ?? false) {
      _positions?.cancel();
      _positions = null;
      return;
    }
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final foreground =
        lifecycle == null || lifecycle == AppLifecycleState.resumed;
    if (_visitId != null && _positions == null && foreground) {
      unawaited(_subscribe());
      _startFlushTimer();
    }
  }

  /// Buffers a fix the work-day capture took while [visitId] was running.
  /// Same buffer, same flush as a fix from this tracker's own stream; a fix
  /// already buffered (a drain replayed after a crash) is ignored.
  Future<void> ingest(int visitId, TrailPoint point) async {
    final key = _BufferedPoint(visitId: visitId, point: point).key;
    if (_readBuffer().any((b) => b.key == key)) return;
    await _buffer(visitId, point);
  }

  Future<void> _resolveDeviceId() async {
    if (_deviceIdValue != null || deviceId == null) return;
    try {
      _deviceIdValue = await deviceId!();
    } catch (e) {
      appLog('[VisitTrailTracker] device id unavailable: $e');
    }
  }

  Future<void> _subscribe() async {
    await _positions?.cancel();
    _positions = null;
    // The work-day capture is sampling already; see [feed].
    if (feed?.isActive ?? false) return;
    final permitted = await locationService.ensurePermission();
    if (!permitted) {
      // No permission is not an error to raise here: the visit itself could not
      // have been started without a fix, so this only happens if the user
      // revoked it mid-visit. The trail simply stops growing.
      appLog('[VisitTrailTracker] location permission unavailable; not tracking');
      return;
    }
    _positions = locationService
        .watch(distanceFilter: AppConstants.trailMinDistanceMeters.round())
        .listen(
          _onPosition,
          onError: (Object e) =>
              appLog('[VisitTrailTracker] position stream error: $e'),
          cancelOnError: false,
        );
  }

  void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(
      AppConstants.trailFlushInterval,
      (_) => unawaited(flushNow(probe: true)),
    );
  }

  @override
  // ignore: avoid_renaming_method_parameters
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    switch (lifecycle) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Drop the subscription rather than let it run unattended — see the
        // foreground-only note on the class. Flush on the way out so the points
        // collected during this stretch aren't stranded on the device if the
        // app is killed while backgrounded.
        _positions?.cancel();
        _positions = null;
        _flushTimer?.cancel();
        _flushTimer = null;
        if (_visitId != null) unawaited(flushNow());
        break;
      case AppLifecycleState.resumed:
        if (_visitId != null && _positions == null) {
          unawaited(_subscribe());
          _startFlushTimer();
          unawaited(flushNow(probe: true));
        }
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Sampling
  // ---------------------------------------------------------------------------

  /// A device-clock instant expressed on the server's clock.
  DateTime _serverTime(DateTime deviceTime) =>
      serverClock?.toServer(deviceTime) ?? deviceTime.toUtc();

  void _onPosition(Position pos) {
    final visitId = _visitId;
    if (visitId == null) return;

    // Android hands a new subscription its last known location first, stamped
    // with the time it was originally taken. That fix predates this visit's
    // start (often it *is* the fix the Start action itself used), and the
    // server refuses anything older than `start_datetime` — so it would only
    // ever come back as a rejected point and a "positions could not be saved"
    // warning for the rep.
    final since = _trackingSince;
    if (since != null && pos.timestamp.isBefore(since)) return;

    // A wildly uncertain fix is worse than no fix: it puts a vertex hundreds of
    // metres off the real route and the drawn thread jumps sideways and back.
    // The server measures `tracked_distance_km` through those vertices too, so
    // a single bad sample inflates the reported distance as well.
    final accuracy = pos.accuracy;
    if (accuracy > 0 && accuracy > AppConstants.trailMaxAccuracyMeters) {
      return;
    }

    // `distanceFilter` on the stream already does most of this, but it is
    // advisory on some platforms and says nothing about time. Enforcing both
    // here keeps the trail's density the same on every device.
    final last = _lastKept;
    if (last != null) {
      final moved = haversineMeters(
          last.latitude, last.longitude, pos.latitude, pos.longitude);
      final elapsed = pos.timestamp.difference(last.timestamp).abs();
      if (moved < AppConstants.trailMinDistanceMeters &&
          elapsed < AppConstants.trailMinInterval) {
        return;
      }
    }
    _lastKept = pos;

    unawaited(_buffer(
      visitId,
      TrailPoint(
        latitude: pos.latitude,
        longitude: pos.longitude,
        // The fix's own time, not the upload time: this is the field the server
        // orders and measures the trail by. Only the clock it is read against
        // is corrected, never the moment itself.
        loggedAt: _serverTime(pos.timestamp),
        accuracy: accuracy > 0 ? accuracy : null,
        altitude: pos.altitude,
        speed: pos.speed >= 0 ? pos.speed : null,
        heading: pos.heading >= 0 ? pos.heading : null,
        deviceId: _deviceIdValue,
      ),
    ));
  }

  /// Records a point the user asked for explicitly (not from the stream), e.g.
  /// a "mark my position" tap. Goes through the same buffer so it is as
  /// crash-safe and as offline-tolerant as an automatic one. [loggedAt] is
  /// device time.
  Future<void> addManualPoint({
    required int visitId,
    required double latitude,
    required double longitude,
    DateTime? loggedAt,
    double? accuracy,
    String? location,
  }) async {
    await _buffer(
      visitId,
      TrailPoint(
        latitude: latitude,
        longitude: longitude,
        loggedAt: _serverTime(loggedAt ?? DateTime.now()),
        accuracy: accuracy,
        location: location,
        deviceId: _deviceIdValue,
      ),
    );
    await flushNow();
  }

  Future<void> _buffer(int visitId, TrailPoint point) async {
    final buffer = _readBuffer();
    buffer.add(_BufferedPoint(visitId: visitId, point: point));
    // Hard ceiling so a phone that spends a week offline can't grow the
    // preferences blob without bound. The oldest fixes go first: the recent
    // path is the one still worth uploading.
    if (buffer.length > AppConstants.trailMaxBufferedPoints) {
      final overflow = buffer.length - AppConstants.trailMaxBufferedPoints;
      buffer.removeRange(0, overflow);
      appLog('[VisitTrailTracker] buffer full; dropped $overflow oldest fix(es)');
      _dropped.add(overflow);
    }
    await _writeBuffer(buffer);
    if (buffer.length >= AppConstants.trailFlushBatchSize) {
      unawaited(flushNow());
    }
  }

  // ---------------------------------------------------------------------------
  // Flushing
  // ---------------------------------------------------------------------------

  /// Pushes everything buffered to the server, one batch per visit.
  ///
  /// When a flush is already running this waits for it and then flushes again,
  /// rather than returning at once. End awaits this to get the route onto the
  /// server while the visit is still open; with an early return, a timer tick
  /// that happened to be mid-flush made that await resolve immediately and the
  /// tail of the route was still on the device when the visit closed.
  ///
  /// [probe] sends even while [ConnectivityStatus] reads offline. That flag
  /// only turns back to online after *some* request succeeds, so if the
  /// tracker never tried while it was down, a quiet app (nothing else calling
  /// the server) would keep the route stuck on the device indefinitely after
  /// the network had long returned. The periodic timer and app-resume flushes
  /// are that probe; a failed attempt costs one fast request and keeps every
  /// point. Point-count triggers do not probe, so a dead zone is not hammered
  /// once per fix.
  ///
  /// Never throws: it runs from a timer, a connectivity callback and a lifecycle
  /// callback, none of which have anywhere to put an error.
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

      final byVisit = <int, List<_BufferedPoint>>{};
      for (final b in buffer) {
        byVisit.putIfAbsent(b.visitId, () => []).add(b);
      }

      final survivors = <_BufferedPoint>[];
      var landed = false;
      var droppedTotal = 0;

      for (final entry in byVisit.entries) {
        final visitId = entry.key;
        final points = entry.value;

        // A Start still waiting in the offline queue means the server has this
        // visit as `approved`, and every point would come back "visit has not
        // been started". Hold them until the queue has replayed the Start —
        // that replay fires a connectivity-driven flush of its own.
        if (_hasQueuedAction(visitId)) {
          survivors.addAll(points);
          continue;
        }

        final (kept, didLand, droppedHere) = await _flush(visitId, points);
        survivors.addAll(kept);
        landed = landed || didLand;
        droppedTotal += droppedHere;
      }

      // Points buffered while the network calls were in flight are still only
      // on disk: re-read and keep them, or this write would erase them.
      final sentKeys = {for (final b in buffer) b.key};
      final arrivedMeanwhile =
          _readBuffer().where((b) => !sentKeys.contains(b.key));
      await _writeBuffer([...survivors, ...arrivedMeanwhile]);
      if (droppedTotal > 0) _dropped.add(droppedTotal);
      if (landed) _revision.value++;
    } catch (e) {
      appLog('[VisitTrailTracker] flush failed: $e');
    }
  }

  bool _hasQueuedAction(int visitId) {
    final queue = pendingActions?.call();
    if (queue == null) return false;
    try {
      return queue.pending.any((a) => a.visitId == visitId);
    } catch (_) {
      return false;
    }
  }

  /// Sends one visit's buffered points, in batches until they're gone or the
  /// server stops taking them. Returns `(keep, landed, dropped)`.
  ///
  /// It loops rather than sending a single batch per tick: a rep who spent the
  /// morning out of coverage can have well over [AppConstants.trailMaxBatchSize]
  /// fixes waiting, and one batch per two-minute timer would take the better
  /// part of an hour to drain a buffer that reconnecting could clear in
  /// seconds.
  Future<(List<_BufferedPoint>, bool, int)> _flush(
    int visitId,
    List<_BufferedPoint> points,
  ) async {
    // Oldest first, so a run that stops early still leaves a contiguous path
    // behind on the server and a contiguous remainder in the buffer.
    points.sort((a, b) => a.point.loggedAt.compareTo(b.point.loggedAt));

    var remaining = points;
    final keep = <_BufferedPoint>[];
    var landed = false;
    var dropped = 0;

    while (remaining.isNotEmpty) {
      final batch = remaining.take(AppConstants.trailMaxBatchSize).toList();
      final rest = remaining.skip(batch.length).toList();
      try {
        final result = await repository.logLocations(
          visitId,
          [for (final b in batch) b.point],
        );

        // Partial success is the normal case, not an error: `rejected[].index`
        // is the position in the array just sent, and every index *not* listed
        // was created. Accepted points simply leave the buffer.
        final refusedAt = {for (final r in result.rejected) r.index: r};
        final serverNow = serverClock?.now() ?? DateTime.now().toUtc();
        for (var i = 0; i < batch.length; i++) {
          final refusal = refusedAt[i];
          if (refusal == null) continue;
          final b = batch[i];
          // Every refusal is permanent except one: "cannot be dated in the
          // future", which time itself cures. The message is translated, so it
          // is recognised by the point rather than the text — a fix still ahead
          // of the server's clock is kept and retried (bounded, like a refused
          // batch). Anything else (out of range, unparseable, before the start,
          // after the end) would be refused identically forever, so it is
          // dropped — but never silently: it was real field evidence.
          if (b.point.loggedAt.isAfter(serverNow) &&
              b.attempts + 1 < AppConstants.trailMaxFlushAttempts) {
            keep.add(b.withAttempt());
            appLog('[VisitTrailTracker] visit $visitId point $i dated ahead of '
                'the server; retrying later: ${refusal.error}');
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
        if (e.code == ApiErrorCode.network ||
            e.code == ApiErrorCode.timeout ||
            e.code == ApiErrorCode.server) {
          // Unreachable again mid-drain — keep what is left, retry next tick.
          return ([...keep, ...remaining], landed, dropped);
        }
        // The whole call was refused (the visit moved on, rights changed).
        // Count the attempts rather than either retrying forever or dropping on
        // the first refusal: a visit whose Start is still replaying from the
        // offline queue refuses a batch now and accepts it a minute later.
        final retried = [
          for (final b in remaining)
            if (b.attempts + 1 < AppConstants.trailMaxFlushAttempts)
              b.withAttempt()
        ];
        dropped += remaining.length - retried.length;
        appLog('[VisitTrailTracker] visit $visitId batch refused '
            '(${e.code} ${e.serverMessage ?? ''}); keeping ${retried.length}, '
            'dropping ${remaining.length - retried.length}');
        return ([...keep, ...retried], landed, dropped);
      }
    }
    return (keep, landed, dropped);
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  List<_BufferedPoint> _readBuffer() {
    final raw = prefs.getString(_bufferKey);
    if (raw == null || raw.isEmpty) return [];
    final List<dynamic> list;
    try {
      list = jsonDecode(raw) as List;
    } catch (_) {
      return [];
    }
    // Entry by entry: one unreadable record must not discard a whole visit's
    // worth of collected path, which is exactly the bug the pending-actions
    // queue had to fix for the same reason.
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
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_connectivityListener != null) {
      connectivity.removeListener(_connectivityListener!);
    }
    _positions?.cancel();
    _flushTimer?.cancel();
    _dropped.close();
    _pendingCount.dispose();
    _revision.dispose();
  }
}

/// A buffered fix plus the visit it belongs to and how many times the server
/// has refused the batch carrying it.
class _BufferedPoint {
  final int visitId;
  final TrailPoint point;
  final int attempts;

  const _BufferedPoint({
    required this.visitId,
    required this.point,
    this.attempts = 0,
  });

  /// Identity of the fix itself (not of this attempt count), used to tell the
  /// points a flush sent apart from ones buffered while it was running.
  String get key =>
      '$visitId|${point.loggedAt.microsecondsSinceEpoch}|'
      '${point.latitude}|${point.longitude}';

  _BufferedPoint withAttempt() => _BufferedPoint(
        visitId: visitId,
        point: point,
        attempts: attempts + 1,
      );

  Map<String, dynamic> toJson() => {
        'v': visitId,
        'n': attempts,
        'p': point.toJson(),
      };

  static _BufferedPoint? tryFromJson(Map<String, dynamic> j) {
    final visitId = (j['v'] as num?)?.toInt();
    final raw = j['p'];
    if (visitId == null || raw is! Map) return null;
    final point = TrailPoint.tryFromJson(Map<String, dynamic>.from(raw));
    if (point == null) return null;
    return _BufferedPoint(
      visitId: visitId,
      point: point,
      attempts: (j['n'] as num?)?.toInt() ?? 0,
    );
  }
}
