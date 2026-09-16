import 'package:flutter/widgets.dart';

import '../../shared/extensions/context_extensions.dart';
import 'app_date.dart';

/// Localized "time ago" formatting shared across the app so no screen hardcodes
/// its own (previously Arabic-only) relative-time strings.
///
/// Falls back to an absolute `yyyy-MM-dd` date once the gap exceeds a week,
/// which reads the same in both languages.
class RelativeTime {
  RelativeTime._();

  static const int _daysPerWeek = 7;

  /// A time slightly in the future (the server's clock ahead of the device's)
  /// reads as "now" rather than a negative count.
  static String format(BuildContext context, DateTime when) {
    final diff = DateTime.now().difference(when);
    final s = context.s;
    if (diff.inMinutes < 1) return s.relativeNow;
    if (diff.inMinutes < 60) return s.relativeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return s.relativeHoursAgo(diff.inHours);
    if (diff.inDays < _daysPerWeek) return s.relativeDaysAgo(diff.inDays);
    return AppDate.isoDate(when);
  }
}
