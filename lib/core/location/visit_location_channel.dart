import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'journal_entry.dart';

/// One position the native visit capture recorded and Flutter has not taken
/// over yet.
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

  /// The visit that was being recorded when the fix was taken.
  final int visitId;

  const CapturedFix({
    required this.seq,
    required this.deviceTime,
    required this.latitude,
    required this.longitude,
    required this.visitId,
    this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
  });

  /// Null for a malformed entry — including one without a visit, which the
  /// native side never writes: a fix that cannot be attributed to a visit is
  /// not recorded at all.
  static CapturedFix? tryParse(Map<dynamic, dynamic> raw) {
    final geo = JournalGeo.tryParse(raw);
    final visit = raw['v'];
    if (geo == null || visit is! num) return null;
    return CapturedFix(
      seq: geo.seq,
      deviceTime: geo.deviceTime,
      latitude: geo.latitude,
      longitude: geo.longitude,
      accuracy: geo.accuracy,
      altitude: geo.altitude,
      speed: geo.speed,
      heading: geo.heading,
      visitId: visit.toInt(),
    );
  }
}

/// What the native capture reports about itself.
typedef CaptureStatus = ({bool active, bool running, int? visitId});

/// Dart side of the native visit capture: `VisitLocationChannel.kt` (Android
/// foreground service) and `VisitLocation.swift` (iOS background location
/// updates). Both implement the same calls and the same journal, so
/// `VisitTrailTracker` drives either one identically.
///
/// Elsewhere ([isAvailable] false) the tracker falls back to a foreground
/// position stream. Subclassed in tests.
class VisitLocationChannel {
  const VisitLocationChannel();

  static const MethodChannel _channel =
      MethodChannel('net.digitalharbor.visits/visit_location');

  bool get isAvailable => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Starts (or retargets) capture for [visitId]. Fixes stamped before
  /// [since] (device clock) are ignored. [seedLatitude]/[seedLongitude] is the
  /// position the Start action already put on the trail.
  Future<void> start({
    required int visitId,
    required DateTime since,
    required double minDistanceMeters,
    required Duration minInterval,
    required double maxAccuracyMeters,
    required String title,
    required String text,
    double? seedLatitude,
    double? seedLongitude,
  }) =>
      _channel.invokeMethod<void>('start', {
        'visitId': visitId,
        'sinceMs': since.millisecondsSinceEpoch,
        'minDistanceMeters': minDistanceMeters,
        'minIntervalMs': minInterval.inMilliseconds,
        'maxAccuracyMeters': maxAccuracyMeters,
        'title': title,
        'text': text,
        'seedLatitude': seedLatitude,
        'seedLongitude': seedLongitude,
      });

  /// Stops capture. Takes effect for any fix arriving after this returns.
  Future<void> stop() => _channel.invokeMethod<void>('stop');

  /// `active`: a visit is configured for capture. `running`: the capture is
  /// alive in this process right now.
  Future<CaptureStatus> status() async {
    final raw = await _channel.invokeMapMethod<String, dynamic>('status');
    final visit = raw?['visitId'];
    return (
      active: raw?['active'] == true,
      running: raw?['running'] == true,
      visitId: visit is num ? visit.toInt() : null,
    );
  }

  Future<List<CapturedFix>> read({int max = journalReadBatch}) async {
    final raw = await _channel.invokeListMethod<dynamic>('read', {'max': max});
    return [
      for (final m in raw ?? const [])
        if (m is Map) ?CapturedFix.tryParse(m),
    ];
  }

  Future<void> ack(int throughSeq) =>
      _channel.invokeMethod<void>('ack', {'throughSeq': throughSeq});
}
