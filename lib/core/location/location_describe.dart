// location_describe.dart — turns a fix into the human-readable text that gets
// stored on the visit as `start_location` / `end_location`.
//
// Why this exists: `/api/visit/start` and `/api/visit/end` have always accepted
// a `location` string, `dh.visit` has always had `start_location`/`end_location`
// char fields, and the visit detail page has always rendered them — but the app
// never sent one, so every visit on the live database has those fields empty
// (verified 2026-07-16: 2 of 15 started visits carry text, and both were seeded
// by a script, not by the app). A manager reading a visit saw raw coordinates
// or nothing.
//
// Reverse geocoding is best-effort by design. It needs network and, on Android,
// a Play-Services geocoder — neither is guaranteed for a rep in a dead zone,
// which is exactly when a visit still has to start. So every failure path
// degrades to the coordinate string rather than throwing: text is evidence, but
// coordinates are *the* evidence, and they are already on the record.
import 'package:geocoding/geocoding.dart';

import '../constants/app_locales.dart';
import '../utils/app_log.dart';

class LocationDescriber {
  /// Reverse-geocode timeout. Deliberately short: this runs inline on the
  /// Start/End tap, after the GPS fix has already cost up to 10s. A rep waiting
  /// to check in must not be made to wait on a nice-to-have label.
  static const _timeout = Duration(seconds: 5);

  /// Decimal places in the coordinate fallback: 5 ≈ 1 m, finer than any
  /// consumer phone's fix.
  static const int _coordinateDecimals = 5;

  /// Separators between address parts, per script. The label is stored on the
  /// visit and read back by the reviewer, so English must read as English.
  static const String _arabicSeparator = '، ';
  static const String _latinSeparator = ', ';

  /// A human-readable label for [latitude]/[longitude], never null and never
  /// throwing. Falls back to `"24.71360, 46.67530"` when geocoding is
  /// unavailable, so the field is always populated with *something* true.
  ///
  /// [localeIdentifier] should be the app's current locale (`ar` / `en`) so the
  /// stored text matches what the reviewing manager reads.
  Future<String> describe(
    double latitude,
    double longitude, {
    String? localeIdentifier,
  }) async {
    final fallback = formatCoordinates(latitude, longitude);
    try {
      // The locale is process-wide state in this plugin, not a per-call
      // argument, so it is set immediately before the lookup.
      if (localeIdentifier != null) {
        await setLocaleIdentifier(localeIdentifier);
      }
      final places =
          await placemarkFromCoordinates(latitude, longitude).timeout(_timeout);
      if (places.isEmpty) return fallback;
      final label = _format(places.first, localeIdentifier);
      return label.isEmpty ? fallback : label;
    } catch (e) {
      // Offline, no geocoder backend, or timed out — all expected in the field.
      appLog('[LocationDescriber] reverse geocode failed: $e');
      return fallback;
    }
  }

  /// The coordinate form used as the fallback, and by callers that want the
  /// numbers regardless. 5 decimals ~= 1m, which is finer than any consumer
  /// phone's fix.
  static String formatCoordinates(double latitude, double longitude) =>
      '${latitude.toStringAsFixed(_coordinateDecimals)}$_latinSeparator'
      '${longitude.toStringAsFixed(_coordinateDecimals)}';

  /// Builds "street, district, city" from whichever parts the platform filled
  /// in. Android and iOS populate different subsets of [Placemark], and empty
  /// strings are common on both, so this filters rather than assuming.
  String _format(Placemark p, String? locale) {
    final parts = <String>[
      if (_has(p.street)) p.street!,
      if (_has(p.subLocality)) p.subLocality!,
      if (_has(p.locality)) p.locality!,
      // Only fall back to the wider area when nothing more precise came back —
      // "Riyadh Province, Saudi Arabia" alone is not useful proof of presence.
      if (!_has(p.street) && !_has(p.subLocality) && !_has(p.locality)) ...[
        if (_has(p.administrativeArea)) p.administrativeArea!,
        if (_has(p.country)) p.country!,
      ],
    ];
    // De-duplicate: Android often repeats the locality in two fields.
    final seen = <String>{};
    final separator = locale != null && AppLocales.isArabicTag(locale)
        ? _arabicSeparator
        : _latinSeparator;
    return parts.where((s) => seen.add(s)).join(separator);
  }

  bool _has(String? s) => s != null && s.trim().isNotEmpty;
}
