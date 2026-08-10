import 'package:flutter/foundation.dart';

/// Build-time configuration sourced from `--dart-define` flags.
///
/// The app is **multi-tenant**: every company runs its own Odoo server, so the
/// backend URL and database are normally entered once by the user on the
/// server-setup screen and persisted via `ServerConfigRepository`. These
/// `--dart-define`s are only a seed for CI and automated builds.
///
/// Usage:
///   flutter run --dart-define=API_BASE_URL=https://odoo.example.com \
///               --dart-define=ODOO_DATABASE=prod_db_name
///
/// **A release binary never carries a company's URL or database name unless it
/// was explicitly passed at build time.** Debug builds behave the same by
/// default: they start blank and show the server-setup screen, exactly like a
/// customer's (or an App Store reviewer's) first launch. Opt back into the test
/// backend with `--dart-define=DEV_SEED_SERVER=true` — see [_devSeedServer].
class AppEnvironment {
  AppEnvironment._();

  // Dev-only seeds. Gated behind [_devSeedServer] + `kReleaseMode` below rather
  // than used as `defaultValue`, because a `defaultValue` is compiled into
  // *every* build — including a store release, which would then ship one
  // customer's server address to every other customer.
  static const String _devSeedBaseUrl =
      'https://thedigitalharbor-dh-visits-new.odoo.com';
  static const String _devSeedDatabase =
      'thedigitalharbor-dh-visits-new-main-35787218';

  /// Opt-in shortcut for local work: `flutter run --dart-define=DEV_SEED_SERVER=true`
  /// pre-fills the test backend so the setup screen is skipped.
  ///
  /// **Off by default on purpose.** While it was on, every debug run jumped
  /// straight to /login, so the first screen a real user sees was the one screen
  /// nobody on the team ever saw — and an App Store reviewer was blocked on it
  /// in build 1.0 (4) (guideline 2.1, "provide server address").
  static const bool _devSeedServer = bool.fromEnvironment('DEV_SEED_SERVER');

  static bool get _useDevSeed => _devSeedServer && !kReleaseMode;

  static const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _definedDatabase =
      String.fromEnvironment('ODOO_DATABASE');

  /// Build-time backend base URL fallback (no trailing slash), or `''` when
  /// none was supplied — in which case the app asks for it on the setup screen.
  static String get baseUrl => _definedBaseUrl.isNotEmpty
      ? _definedBaseUrl
      : (_useDevSeed ? _devSeedBaseUrl : '');

  /// Build-time Odoo database fallback, or `''` when none was supplied.
  static String get database => _definedDatabase.isNotEmpty
      ? _definedDatabase
      : (_useDevSeed ? _devSeedDatabase : '');

  /// Build flavour name surfaced in logs / settings screen.
  static const String flavor = String.fromEnvironment(
    'APP_FLAVOR',
    defaultValue: 'dev',
  );

  static bool get isProduction => flavor == 'production';

  /// Sentry DSN for crash reporting. Empty string disables Sentry entirely
  /// (so local debug builds don't spam your Sentry quota — only release / CI
  /// builds pass it via --dart-define-from-file).
  static const String sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );

  static bool get sentryEnabled => sentryDsn.isNotEmpty;

  /// Sample rate for performance/transaction monitoring, expressed as a
  /// percentage (0--100). Default 10 keeps Sentry cost low in production;
  /// raise to 100 in staging to validate.
  static const int _sentryTracesPercent = int.fromEnvironment(
    'SENTRY_TRACES_PERCENT',
    defaultValue: 10,
  );

  static double get sentryTracesSampleRate => _sentryTracesPercent / 100.0;
}
