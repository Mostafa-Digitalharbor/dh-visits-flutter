/// Build-time configuration sourced from `--dart-define` flags.
///
/// Why: the Odoo backend URL and database name differ per environment
/// (dev / staging / production) and the previous hard-coded trial URL would
/// have stopped working when the trial expired. Keeping these as compile-time
/// constants lets us bake the production URL into the store-released binary
/// while still allowing devs to point at a local/staging instance.
///
/// Usage:
///   flutter run --dart-define=API_BASE_URL=https://odoo.example.com \
///               --dart-define=ODOO_DATABASE=prod_db_name
///
/// Defaults match the existing dev/trial instance so local builds keep
/// working out of the box.
class AppEnvironment {
  AppEnvironment._();

  /// Optional build-time backend base URL fallback (no trailing slash).
  ///
  /// The app is multi-tenant: each company runs its own Odoo server, so the
  /// base URL is normally entered by the user on the server-setup screen and
  /// persisted via [ServerConfigRepository]. This `--dart-define` only acts as
  /// a seed for CI / automated builds; it is intentionally empty by default so
  /// release binaries never ship a hard-coded company URL.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Optional build-time Odoo database fallback. Like [baseUrl], this is
  /// normally provided per-company on the server-setup screen; the
  /// `--dart-define` is only a convenience seed for dev/CI builds.
  static const String database = String.fromEnvironment(
    'ODOO_DATABASE',
    defaultValue: '',
  );

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
