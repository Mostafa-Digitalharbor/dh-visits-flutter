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

  // ---- Map tiles (OpenStreetMap) ----
  // Shared by every map in the app via [AppMapTileLayer] so tiles render
  // identically everywhere. Change the provider in one place here.
  static const String mapTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String mapUserAgent = 'com.digitalharbor.location_gps';

  /// OSM tiles only exist up to zoom 19; beyond that flutter_map upscales the
  /// last available tile instead of showing blank squares.
  static const int mapMaxNativeZoom = 19;

  /// Fallback map center (Cairo) used when no real coordinate is available.
  static const double mapFallbackLat = 30.0444;
  static const double mapFallbackLng = 31.2357;

  /// Assumed average city driving speed (km/h) for route drive-time estimates.
  static const double driveSpeedKmh = 30.0;

  /// Max distance (meters) between the customer office and the employee's
  /// check-in / check-out GPS for the visit to count as "in range". On a
  /// vanilla Odoo there's no server-side range field, so the app computes
  /// the badge itself from the customer + check-in coordinates.
  static const double checkInRangeMeters = 200.0;

  // ---- Standard Odoo models the app talks to via generic JSON-RPC ----
  static const String partnerModel = 'res.partner';
  static const String calendarEventModel = 'calendar.event';
  static const String calendarEventTypeModel = 'calendar.event.type';
  static const String usersModel = 'res.users';

  /// Visits live in the `dh_visit_management` Odoo module. The visit record is
  /// `dh.visit` with a full approval workflow (`state`: draft → submitted →
  /// waiting_* approval → approved → in_progress → done, plus rejected /
  /// cancelled / escalated / reschedule_requested). A visit is tied to a
  /// project or opportunity (the customer auto-fills from it).
  ///
  /// Visit *actions* go through the module's dedicated `/api/visit/*` REST
  /// endpoints (see [Endpoints]); manager list reads and the rich detail
  /// fields not exposed by the REST payload are read via `call_kw` on the
  /// models below (record rules enforce access server-side).
  static const String visitModel = 'dh.visit';
  static const String visitParticipantModel = 'dh.visit.participant';
  static const String projectModel = 'project.project';
  static const String crmLeadModel = 'crm.lead';

  // ---- dh_visit_management security groups (res.groups) ----
  // The logged-in user's visit role is derived by matching their `group_ids`
  // against these (highest wins). See AuthUser.visitRole.
  static const int groupVisitUserId = 41; // dh_visit_management.group_visit_user
  static const int groupVisitManagerId = 42; // group_visit_manager
  static const int groupVisitProjectManagerId = 43; // group_visit_project_manager
  static const int groupVisitAdminId = 44; // group_visit_admin

  // Attendance: the salesperson's check-in / check-out is also mirrored to
  // Odoo's standard `hr.attendance` (with GPS in the native `in_*` / `out_*`
  // fields) so it shows up in the Attendances module. Each app user is matched
  // to an `hr.employee` via its `user_id`.
  static const String hrAttendanceModel = 'hr.attendance';
  static const String hrEmployeeModel = 'hr.employee';
}
