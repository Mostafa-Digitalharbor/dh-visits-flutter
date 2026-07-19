import 'package:flutter/widgets.dart';

import '../../shared/extensions/context_extensions.dart';

/// Duration rendering used across the app.
///
/// Four spellings of these two formats had grown up in view files — two of them
/// character-identical — and the localized one lived as a bare function inside
/// a page. Keeping them together means "1 h 20 m" reads the same everywhere and
/// the padding rules can't drift.
extension DurationFormat on Duration {
  /// Zero-padded `HH:MM`, e.g. `01:20`. Hours are not wrapped at 24 — a visit
  /// left running overnight should read `27:04`, not `03:04`.
  String get clock {
    final h = inHours.toString().padLeft(2, '0');
    final m = (inMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Zero-padded `HH:MM:SS` — for the live timer on the active-visit bar,
  /// where seconds ticking is the signal that tracking is running.
  String get clockWithSeconds {
    final s = (inSeconds % 60).toString().padLeft(2, '0');
    return '$clock:$s';
  }

  /// Localized and unit-suffixed, e.g. `1 h 20 m` / `1 س 20 د`. Drops the hour
  /// part under an hour, and the minute part on an exact hour, so a duration
  /// never reads "2 h 0 m".
  String localized(BuildContext context) {
    final s = context.s;
    final h = inHours;
    final m = inMinutes % 60;
    if (h > 0) {
      return m > 0
          ? '$h ${s.wfHoursShort} $m ${s.wfMinutesShort}'
          : '$h ${s.wfHoursShort}';
    }
    return '$m ${s.wfMinutesShort}';
  }
}
