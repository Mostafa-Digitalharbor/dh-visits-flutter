// app_date.dart — locale-aware date/time formatting.
//
// Two problems live here, and both are invisible until you run the app in
// Arabic.
//
// 1. `DateFormat` with no locale resolves through `Intl.defaultLocale`, which
//    is never wired to the app's `SettingsCubit` locale. A bare
//    `DateFormat('MMM d')` therefore renders English month and weekday names
//    ("Wed, Jul 15") on an otherwise Arabic screen. Symbolic patterns must be
//    given the active locale explicitly.
//
// 2. Once you *do* pass `ar`, intl switches the numbering system too and
//    formats "14:30" as "١٤:٣٠". Nothing else in this app does that: counts,
//    distances and the `{count}` placeholders in the ARBs are plain Dart
//    interpolation, so they stay Latin. Left alone, a visit card would read
//    "١٥ يوليو، ١٤:٣٠" directly above a "5 د" badge and a "200 م" distance.
//    So we localize the *words* and normalize the *digits* back to Latin.
//
// Never call `DateFormat` directly in a widget for a pattern with symbolic
// fields (MMM / EEE / MMMM) — go through here so both rules hold. Formatters
// are returned as [AppDateFormat] rather than a raw `DateFormat` precisely so
// the digit normalization can't be bypassed by calling `.format()`.
//
// `main._bootstrap` calls `initializeDateFormatting`, without which the
// non-`en` symbol data these need isn't loaded.
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// A [DateFormat] bound to the app locale, whose output is digit-normalized.
/// Reuse one across several values in a single `build`.
class AppDateFormat {
  final DateFormat _inner;
  const AppDateFormat._(this._inner);

  String format(DateTime when) => AppDate.toLatinDigits(_inner.format(when));
}

class AppDate {
  AppDate._();

  /// Arabic-Indic digits (U+0660–U+0669) → ASCII.
  static final RegExp _arabicIndic = RegExp('[٠-٩]');

  /// The BCP-47 tag intl should format with, taken from the active
  /// `Localizations` scope (which `MaterialApp.locale` drives).
  static String localeOf(BuildContext context) =>
      Localizations.localeOf(context).toLanguageTag();

  /// Rewrites Arabic-Indic digits to Latin, leaving letters untouched, so
  /// dates match every other number in the UI. See the header note.
  static String toLatinDigits(String value) => value.replaceAllMapped(
        _arabicIndic,
        (m) => '${m.group(0)!.codeUnitAt(0) - 0x0660}',
      );

  static AppDateFormat _fmt(String pattern, BuildContext context) =>
      AppDateFormat._(DateFormat(pattern, localeOf(context)));

  // ---- Formatters (reuse across several values in one build) ----

  /// "Wed, Jul 15 • 14:30" / "الأربعاء، 15 يوليو • 14:30"
  static AppDateFormat weekdayDateTimeFormat(BuildContext context) =>
      _fmt('EEE, MMM d • HH:mm', context);

  /// "Jul 15, 14:30" / "15 يوليو، 14:30"
  static AppDateFormat dateTimeFormat(BuildContext context) =>
      _fmt('MMM d, HH:mm', context);

  /// "Jul 15" / "15 يوليو"
  static AppDateFormat dayMonthFormat(BuildContext context) =>
      _fmt('MMM d', context);

  /// "14:30" — 24h clock.
  static AppDateFormat timeFormat(BuildContext context) =>
      _fmt('HH:mm', context);

  /// "14:30:05" — 24h clock with seconds.
  static AppDateFormat timeWithSecondsFormat(BuildContext context) =>
      _fmt('HH:mm:ss', context);

  // ---- One-shot helpers ----

  static String weekdayDateTime(BuildContext context, DateTime when) =>
      weekdayDateTimeFormat(context).format(when);

  static String dateTime(BuildContext context, DateTime when) =>
      dateTimeFormat(context).format(when);

  static String dayMonth(BuildContext context, DateTime when) =>
      dayMonthFormat(context).format(when);

  static String time(BuildContext context, DateTime when) =>
      timeFormat(context).format(when);

  /// "2026-07-15" — absolute date, reads the same in both languages and needs
  /// no locale (the >1 week fallback in [RelativeTime]).
  static String isoDate(DateTime when) => DateFormat('yyyy-MM-dd').format(when);
}
