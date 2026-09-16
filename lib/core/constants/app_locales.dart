import 'dart:ui';

/// The languages the app ships, and the one it starts in.
///
/// Locale codes used to be compared as bare `'ar'` / `'en'` literals in half a
/// dozen places, each with its own idea of the default.
abstract final class AppLocales {
  static const arabicCode = 'ar';
  static const englishCode = 'en';

  static const arabic = Locale(arabicCode);
  static const english = Locale(englishCode);

  /// The locale used until the user picks one. The app's users are
  /// Arabic-speaking field teams.
  static const fallback = arabic;

  /// Wire formats (dates sent to Odoo) are always rendered in this locale so
  /// Arabic-Indic digits never reach the server.
  static const wireFormatLocale = 'en_US';

  static bool isArabic(Locale locale) => locale.languageCode == arabicCode;

  /// Whether a BCP-47 tag or `AppLocalizations.localeName` is Arabic.
  static bool isArabicTag(String tag) => tag.startsWith(arabicCode);

  /// The locale a stored code resolves to; anything unknown falls back.
  static Locale fromCode(String? code) => switch (code) {
        arabicCode => arabic,
        englishCode => english,
        _ => fallback,
      };
}
