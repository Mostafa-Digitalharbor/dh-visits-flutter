import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One position captured by the native work-day location service and not yet
/// taken over by the Flutter upload queue.
class CapturedFix {
  /// Journal sequence number, strictly increasing across the install. Fixes
  /// are acknowledged by it, which is what removes them from the journal.
  final int seq;

  /// The fix's own time on the **device** clock (not when it was read).
  final DateTime deviceTime;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? altitude;
  final double? speed;
  final double? heading;

  /// The local work-day session the service was capturing for.
  final String sessionUid;

  /// The visit that was running when the fix was taken, if any.
  final int? visitId;

  const CapturedFix({
    required this.seq,
    required this.deviceTime,
    required this.latitude,
    required this.longitude,
    required this.sessionUid,
    this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
    this.visitId,
  });

  static CapturedFix? tryParse(Map<dynamic, dynamic> raw) {
    double? d(Object? v) => v is num ? v.toDouble() : null;
    final seq = raw['seq'];
    final t = raw['t'];
    final lat = d(raw['lat']);
    final lng = d(raw['lng']);
    final session = raw['s'];
    if (seq is! num || t is! num || lat == null || lng == null || session is! String) {
      return null;
    }
    return CapturedFix(
      seq: seq.toInt(),
      deviceTime:
          DateTime.fromMillisecondsSinceEpoch(t.toInt(), isUtc: true),
      latitude: lat,
      longitude: lng,
      accuracy: d(raw['acc']),
      altitude: d(raw['alt']),
      speed: d(raw['spd']),
      heading: d(raw['hdg']),
      sessionUid: session,
      visitId: (raw['v'] as num?)?.toInt(),
    );
  }
}

enum LocationAuthorizationStatus { notDetermined, restricted, denied, whenInUse, always }

/// iOS location authorization as Core Location reports it.
class LocationAuthorization {
  final LocationAuthorizationStatus status;

  /// False while the user turned "Precise Location" off for the app.
  final bool precise;

  /// The `location` background mode is declared (capture can continue in the
  /// background).
  final bool backgroundMode;

  const LocationAuthorization({
    required this.status,
    required this.precise,
    required this.backgroundMode,
  });

  static LocationAuthorization? tryParse(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    return LocationAuthorization(
      status: LocationAuthorizationStatus.values.firstWhere(
        (s) => s.name == raw['status'],
        orElse: () => LocationAuthorizationStatus.denied,
      ),
      precise: raw['precise'] == true,
      backgroundMode: raw['backgroundMode'] == true,
    );
  }
}

/// Dart side of the native work-day capture: `WorkdayChannel.kt` (Android
/// foreground service) and `WorkdayLocation.swift` (iOS background location
/// updates). Both implement the same calls and the same journal, so
/// `WorkdayTracker` drives either one identically.
///
/// Elsewhere ([isAvailable] false) the work-day tracker falls back to a
/// foreground position stream. Subclassed in tests.
class WorkdayLocationChannel {
  const WorkdayLocationChannel();

  static const MethodChannel _channel =
      MethodChannel('net.digitalharbor.visits/workday_location');

  bool get isAvailable => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  bool get _isIOS => !kIsWeb && Platform.isIOS;

  Future<void> start({
    required String sessionUid,
    required double minDistanceMeters,
    required Duration minInterval,
    required double maxAccuracyMeters,
    required DateTime startedAt,
    required String title,
    required String text,
    int? visitId,
    DateTime? visitSince,
    double? seedLatitude,
    double? seedLongitude,
  }) =>
      _channel.invokeMethod<void>('start', {
        // The day's start position: the service treats it as already recorded.
        'seedLatitude': seedLatitude,
        'seedLongitude': seedLongitude,
        'sessionUid': sessionUid,
        'minDistanceMeters': minDistanceMeters,
        'minIntervalMs': minInterval.inMilliseconds,
        'maxAccuracyMeters': maxAccuracyMeters,
        'startedAtMs': startedAt.millisecondsSinceEpoch,
        'title': title,
        'text': text,
        'visitId': visitId,
        'visitSinceMs': (visitSince ?? DateTime.now()).millisecondsSinceEpoch,
      });

  /// Stops capture. Takes effect for any fix arriving after this returns.
  Future<void> stop() => _channel.invokeMethod<void>('stop');

  Future<void> setVisit(int? visitId, DateTime since) =>
      _channel.invokeMethod<void>('setVisit', {
        'visitId': visitId,
        'sinceMs': since.millisecondsSinceEpoch,
      });

  /// `active`: a work day is configured for capture. `running`: the service
  /// is alive in this process right now.
  Future<({bool active, bool running})> status() async {
    final raw = await _channel.invokeMapMethod<String, dynamic>('status');
    return (
      active: raw?['active'] == true,
      running: raw?['running'] == true,
    );
  }

  Future<List<CapturedFix>> read({int max = 500}) async {
    final raw = await _channel.invokeListMethod<dynamic>('read', {'max': max});
    return [
      for (final m in raw ?? const [])
        if (m is Map) ?CapturedFix.tryParse(m),
    ];
  }

  Future<void> ack(int throughSeq) =>
      _channel.invokeMethod<void>('ack', {'throughSeq': throughSeq});

  /// iOS only (null elsewhere): the current Core Location authorization.
  Future<LocationAuthorization?> authorization() async {
    if (!_isIOS) return null;
    return LocationAuthorization.tryParse(
        await _channel.invokeMapMethod<String, dynamic>('authorization'));
  }

  /// iOS only: asks to upgrade "While Using" to "Always". iOS shows that
  /// prompt at most once; completes when it was answered or not shown.
  Future<LocationAuthorization?> requestAlways() async {
    if (!_isIOS) return null;
    return LocationAuthorization.tryParse(
        await _channel.invokeMapMethod<String, dynamic>('requestAlways'));
  }
}
