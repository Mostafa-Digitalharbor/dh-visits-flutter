import 'package:intl/intl.dart';

import '../../l10n/generated/app_localizations.dart';
import '../constants/app_locales.dart';

/// Number rendering shared by every screen.
///
/// Digits stay Latin in both languages — the same rule [AppDate] applies to
/// dates — so a distance, a count and a time on one card never mix numbering
/// systems. Units come from the ARBs, so their placement and spelling are the
/// translator's call rather than string concatenation's.
abstract final class AppNumber {
  static final _oneDecimal = NumberFormat('#,##0.#', AppLocales.wireFormatLocale);
  static final _twoDecimals = NumberFormat('#,##0.##', AppLocales.wireFormatLocale);
  static final _whole = NumberFormat('#,##0', AppLocales.wireFormatLocale);

  /// Below this a distance reads in meters, above it in kilometers.
  static const double _metersPerKm = 1000;

  /// `1,234` — a count or any whole quantity.
  static String whole(num value) => _whole.format(value);

  /// `12.5` — at most one decimal, none when it would be `.0`.
  static String decimal(num value) => _oneDecimal.format(value);

  /// `3.25 km` / `3.25 كم`.
  static String km(AppLocalizations s, double km, {bool precise = false}) =>
      s.unitKm((precise ? _twoDecimals : _oneDecimal).format(km));

  /// `850 m` / `1.2 km` — the unit that keeps the figure readable.
  static String distance(AppLocalizations s, double meters) =>
      meters < _metersPerKm
          ? s.unitMeters(_whole.format(meters))
          : km(s, meters / _metersPerKm);

  /// `42 km/h`.
  static String speedKmh(AppLocalizations s, double kmh) =>
      s.unitKmh(_whole.format(kmh));

  /// `75%` — the percent sign comes from the ARB (`%` / `٪`).
  static String percent(AppLocalizations s, num value) =>
      s.unitPercentValue(_whole.format(value));

  /// `+5` / `−3` / `0` — an explicit sign for a delta.
  static String signed(num value) {
    if (value == 0) return _oneDecimal.format(0);
    final text = _oneDecimal.format(value.abs());
    return value > 0 ? '+$text' : '\u2212$text';
  }
}
