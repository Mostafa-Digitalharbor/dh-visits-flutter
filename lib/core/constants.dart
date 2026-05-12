class AppConstants {
  AppConstants._();

  static const String baseUrl =
      'https://dh-abdelrahmanwael-odoo-19-test.odoo.com';
  // Odoo.sh trial DBs have format `<subdomain>-pros-<buildId>`, not just the
  // subdomain. Trial instance expires 2026-06-07.
  static const String database = 'dh-abdelrahmanwael-odoo-19-test-pros-31943069';

  static const Duration locationPingInterval = Duration(seconds: 30);
  static const Duration nearbyRefreshInterval = Duration(seconds: 10);

  /// Minimum movement before we re-send live location.
  static const double locationMinDistanceMeters = 5.0;

  /// Even if not moving, send at least this often to stay "online" server-side.
  static const Duration locationHeartbeatInterval = Duration(minutes: 2);

  static const double defaultRadiusMeters = 10.0;
  static const double defaultMapZoom = 19.0;
}
