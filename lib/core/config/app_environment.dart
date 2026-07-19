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
/// was explicitly passed at build time.** A convenience seed still applies to
/// debug/profile builds so a plain `flutter run` reaches the test backend
/// without flags — see [_devSeedBaseUrl].
class AppEnvironment {
  AppEnvironment._();

  // Dev-only seeds. Gated behind `kReleaseMode` below rather than used as
  // `defaultValue`, because a `defaultValue` is compiled into *every* build —
  // including a store release, which would then ship one customer's server
  // address to every other customer.
  static const String _devSeedBaseUrl =
      'https://thedigitalharbor-dh-visits-new.odoo.com';
  static const String _devSeedDatabase =
      'thedigitalharbor-dh-visits-new-main-34241330';

  static const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _definedDatabase =
      String.fromEnvironment('ODOO_DATABASE');

  /// Build-time backend base URL fallback (no trailing slash), or `''` when
  /// none was supplied — in which case the app asks for it on the setup screen.
  static String get baseUrl => _definedBaseUrl.isNotEmpty
      ? _definedBaseUrl
      : (kReleaseMode ? '' : _devSeedBaseUrl);

  /// Build-time Odoo database fallback, or `''` when none was supplied.
  static String get database => _definedDatabase.isNotEmpty
      ? _definedDatabase
      : (kReleaseMode ? '' : _devSeedDatabase);

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
