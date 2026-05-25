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

  /// Backend base URL (no trailing slash).
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://dh-abdelrahmanwael-odoo-19-test.odoo.com',
  );

  /// Odoo database name. For Odoo.sh trial instances this is
  /// `<subdomain>-pros-<buildId>`, not just the subdomain.
  static const String database = String.fromEnvironment(
    'ODOO_DATABASE',
    defaultValue: 'dh-abdelrahmanwael-odoo-19-test-pros-31943069',
  );

  /// Build flavour name surfaced in logs / settings screen.
  static const String flavor = String.fromEnvironment(
    'APP_FLAVOR',
    defaultValue: 'dev',
  );

  static bool get isProduction => flavor == 'production';
}
