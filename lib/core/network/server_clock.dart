import 'dart:io' show HttpDate;

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_log.dart';

/// The difference between this device's wall clock and the Odoo server's.
///
/// The server judges every GPS fix against its **own** clock: a point is
/// refused if it predates `start_datetime`, postdates `end_datetime`, or lies
/// more than five minutes in the future — and `start_datetime`/`end_datetime`
/// themselves are stamped with server time. A phone whose clock runs fast (a
/// manually set time, a device that never synced, an emulator inheriting an
/// unsynced host) therefore produces a trail that is both *misordered* (the End
/// point lands before the last fixes of the route) and *lossy* (fixes from the
/// final minute or two are refused as "after the visit ended").
///
/// Measured live against the test backend on 2026-09-13: the device clock was
/// 87 s ahead, and a trail read back as `start → end → track → track`.
///
/// The offset is learnt passively from the `Date` header every HTTP response
/// carries, so it costs no extra request, and it is persisted so a fix taken
/// offline right after a cold start is still corrected. Resolution is one
/// second (the header's), which is far inside anything the server validates.
class ServerClock {
  ServerClock({this.prefs})
      : _offset = Duration(milliseconds: prefs?.getInt(_prefsKey) ?? 0);

  final SharedPreferences? prefs;

  static const String _prefsKey = 'server_clock_offset_ms_v1';

  /// Changes smaller than this are jitter (latency plus the header's one-second
  /// truncation) and are ignored, so the offset does not wobble between calls.
  static const Duration _jitter = Duration(milliseconds: 1500);

  Duration _offset;

  /// `server time − device time`. Positive when the device clock is behind.
  Duration get offset => _offset;

  /// The server's current time, as best we know it, in UTC.
  DateTime now() => DateTime.now().toUtc().add(_offset);

  /// Re-expresses an instant read off the **device** clock (a GPS fix
  /// timestamp) on the server's clock. The fix keeps its real moment; only the
  /// ruler it is measured with changes.
  DateTime toServer(DateTime deviceTime) => deviceTime.toUtc().add(_offset);

  /// Feeds one response's `Date` header in. [receivedAt] is the device time the
  /// response arrived.
  void observeHttpDate(String? header, {DateTime? receivedAt}) {
    if (header == null || header.isEmpty) return;
    final DateTime serverTime;
    try {
      serverTime = HttpDate.parse(header);
    } catch (_) {
      return;
    }
    final arrived = (receivedAt ?? DateTime.now()).toUtc();
    // The header truncates to the whole second, so the true server time lies
    // somewhere inside the next 1000 ms: centre the estimate on it.
    final candidate =
        serverTime.add(const Duration(milliseconds: 500)).difference(arrived);
    if ((candidate - _offset).abs() < _jitter) return;
    _offset = candidate;
    appLog('[ServerClock] device clock offset now ${candidate.inMilliseconds} ms');
    prefs?.setInt(_prefsKey, candidate.inMilliseconds);
  }
}
