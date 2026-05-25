import 'config/app_environment.dart';

class AppConstants {
  AppConstants._();

  /// Backend base URL. Sourced from `--dart-define=API_BASE_URL=...`.
  /// See [AppEnvironment] for build-flavor overrides.
  static String get baseUrl => AppEnvironment.baseUrl;

  /// Odoo database name. Sourced from `--dart-define=ODOO_DATABASE=...`.
  static String get database => AppEnvironment.database;

  static const Duration locationPingInterval = Duration(seconds: 30);
  static const Duration nearbyRefreshInterval = Duration(seconds: 10);

  /// Minimum movement before we re-send live location.
  static const double locationMinDistanceMeters = 5.0;

  /// Even if not moving, send at least this often to stay "online" server-side.
  static const Duration locationHeartbeatInterval = Duration(minutes: 2);

  static const double defaultRadiusMeters = 10.0;
  static const double defaultMapZoom = 19.0;
}
