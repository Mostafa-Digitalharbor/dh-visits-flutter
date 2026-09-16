import 'package:flutter/widgets.dart';

import '../../shared/extensions/context_extensions.dart';

/// Duration rendering used across the app.
///
/// Four spellings of these two formats had grown up in view files — two of them
/// character-identical — and the localized one lived as a bare function inside
/// a page. Keeping them together means "1 h 20 m" reads the same everywhere and
/// the padding rules can't drift.
///
/// A negative duration (a check-out stamped before the check-in by a skewed
/// clock) renders as zero: Dart's `%` never returns a negative, so it used to
/// come out as "00:59" / "59 m" — a fabricated hour.
extension DurationFormat on Duration {
  static const int _minutesPerHour = 60;
  static const int _secondsPerMinute = 60;
  static const int _clockDigits = 2;

  Duration get _nonNegative => isNegative ? Duration.zero : this;

  static String _pad(int value) =>
      value.toString().padLeft(_clockDigits, '0');

  /// Zero-padded `HH:MM`, e.g. `01:20`. Hours are not wrapped at 24 — a visit
  /// left running overnight should read `27:04`, not `03:04`.
  String get clock {
    final d = _nonNegative;
    return '${_pad(d.inHours)}:${_pad(d.inMinutes % _minutesPerHour)}';
  }

  /// Zero-padded `HH:MM:SS` — for the live timer on the active-visit bar,
  /// where seconds ticking is the signal that tracking is running.
  String get clockWithSeconds =>
      '$clock:${_pad(_nonNegative.inSeconds % _secondsPerMinute)}';

  /// Localized and unit-suffixed, e.g. `1 h 20 m` / `1 س 20 د`. Drops the hour
  /// part under an hour, and the minute part on an exact hour, so a duration
  /// never reads "2 h 0 m". The pattern is the translator's, not concatenated.
  String localized(BuildContext context) {
    final s = context.s;
    final d = _nonNegative;
    final h = d.inHours;
    final m = d.inMinutes % _minutesPerHour;
    if (h == 0) return s.commonDurationMinutes(m);
    return m == 0
        ? s.commonDurationHours(h)
        : s.commonDurationHoursMinutes(h, m);
  }
}
