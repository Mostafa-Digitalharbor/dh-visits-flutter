// journal_entry.dart — the part of a native capture journal entry that is the
// same whatever is being recorded.
//
// Both native captures (visit trail, work day) write the same wire shape for
// *where and when*: a sequence number the entry is acked by, a device-clock
// millisecond stamp, a coordinate and four optional sensor readings. They
// differ only in what the fix is attributed to — a visit id for one, a
// work-day session uid for the other.
//
// The two `CapturedFix` types stay separate on purpose: the visit's visit id
// is required and the work day's is not, and collapsing them into one class
// would make that field nullable for both, moving a compile-time guarantee
// into a runtime `!`. Only the shared parse lives here.
import 'package:flutter/foundation.dart';

/// Most entries taken from a native journal in one `read`.
///
/// Shared by both channels: the visit capture named it and the work-day
/// capture inlined the same `500`, so raising one silently left the other
/// behind.
const int journalReadBatch = 500;

/// The where-and-when common to every journal entry.
@immutable
class JournalGeo {
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

  const JournalGeo({
    required this.seq,
    required this.deviceTime,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
  });

  /// Reads a coordinate out of a platform-channel map, whatever numeric type
  /// the host sent it as. Null for anything that is not a number — an entry
  /// with a string latitude is corrupt, not zero.
  static double? number(Object? v) => v is num ? v.toDouble() : null;

  /// Null when the entry is malformed: a missing sequence number, no
  /// timestamp, or no usable coordinate. The caller then adds whatever the
  /// fix is attributed to, and rejects the entry if that is missing too.
  static JournalGeo? tryParse(Map<dynamic, dynamic> raw) {
    final seq = raw['seq'];
    final t = raw['t'];
    final lat = number(raw['lat']);
    final lng = number(raw['lng']);
    if (seq is! num || t is! num || lat == null || lng == null) return null;
    return JournalGeo(
      seq: seq.toInt(),
      deviceTime: DateTime.fromMillisecondsSinceEpoch(t.toInt(), isUtc: true),
      latitude: lat,
      longitude: lng,
      accuracy: number(raw['acc']),
      altitude: number(raw['alt']),
      speed: number(raw['spd']),
      heading: number(raw['hdg']),
    );
  }
}
