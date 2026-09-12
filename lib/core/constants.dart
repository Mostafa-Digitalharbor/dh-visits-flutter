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

  // ---- Visit GPS trail ----
  // The thread drawn on the map between a visit's Start and End. Tuned for a
  // rep moving by car through a city: dense enough that the path follows the
  // road, sparse enough that an hour of driving is a few hundred points rather
  // than a few thousand.

  /// Minimum movement between two kept fixes. Also the position stream's
  /// `distanceFilter`, so most samples are discarded by the OS before they ever
  /// reach the app.
  static const double trailMinDistanceMeters = 20.0;

  /// Minimum time between two kept fixes, applied together with the distance
  /// rule so crawling traffic doesn't pack the path with near-identical points.
  static const Duration trailMinInterval = Duration(seconds: 20);

  /// A fix less certain than this is discarded rather than drawn: it would put
  /// a vertex hundreds of metres off the route and inflate the server's
  /// `tracked_distance_km` along with it.
  static const double trailMaxAccuracyMeters = 100.0;

  /// How often the buffered fixes are pushed to the server.
  static const Duration trailFlushInterval = Duration(minutes: 2);

  /// Buffer size that triggers an immediate flush without waiting for the timer.
  static const int trailFlushBatchSize = 20;

  /// Upper bound on one `log_locations` call, so a long offline stretch uploads
  /// across several requests instead of one that times out.
  static const int trailMaxBatchSize = 100;

  /// Hard ceiling on the on-device buffer (~10h of driving at the sampling
  /// rates above). Past this the oldest fixes are dropped: the recent path is
  /// the part still worth uploading.
  static const int trailMaxBufferedPoints = 2000;

  /// How many times a batch the server *refuses* is retried before its points
  /// are abandoned. Covers the window where a Start is still replaying from the
  /// offline queue, without retrying a genuinely impossible point forever.
  static const int trailMaxFlushAttempts = 5;

  /// How often an open trail screen re-reads a visit that is still running.
  static const Duration trailLiveRefreshInterval = Duration(seconds: 30);

  static const double defaultRadiusMeters = 10.0;
  static const double defaultMapZoom = 19.0;

  // ---- Map tiles (OpenStreetMap) ----
  // Shared by every map in the app via [AppMapTileLayer] so tiles render
  // identically everywhere. Change the provider in one place here.
  static const String mapTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String mapUserAgent = 'com.digitalharbor.location_gps';

  /// Target of the on-map credit badge ([AppMapAttribution]). OSM's ODbL
  /// licence requires the credit to be visible and to link back here.
  static const String osmCopyrightUrl = 'https://www.openstreetmap.org/copyright';

  /// OSM tiles only exist up to zoom 19; beyond that flutter_map upscales the
  /// last available tile instead of showing blank squares.
  static const int mapMaxNativeZoom = 19;

  /// Interactive zoom bounds shared by every [FlutterMap] in the app.
  static const double mapMaxZoom = 22.0;
  static const double mapMinZoom = 3.0;

  // ---- Per-screen initial camera zoom ----
  // Each map opens at the level that suits what it shows: a single pin can sit
  // tight, a whole day's route has to fit several. Named so the four screens
  // no longer each carry an unexplained number.

  /// Visit detail — one customer pin plus the check-in radius.
  static const double mapZoomVisitDetail = 16.0;

  /// Upper bound when auto-fitting the visit map to its markers, so two very
  /// close points don't slam the camera to street level.
  static const double mapZoomVisitFitMax = 17.0;

  /// Dashboard mini-map — several active employees across a city.
  static const double mapZoomDashboard = 15.0;

  /// Today's route — every stop of the day should be visible at once.
  static const double mapZoomRoute = 14.5;

  // ---- Fetch page sizes ----
  /// Visits shown in a list screen. Comfortably beyond a normal workload
  /// while keeping the payload small enough for a field connection.
  static const int visitsPageLimit = 200;

  /// Rows pulled for a single visit's related records (participants, history).
  static const int visitRelatedLimit = 100;

  /// Upper bound for analytics-style sweeps that aggregate many visits.
  static const int visitsAnalyticsLimit = 500;

  /// Google Maps universal search URL (fallback when the `geo:` scheme has no
  /// handler). Append a `lat,lng` query.
  static const String googleMapsSearchUrl =
      'https://www.google.com/maps/search/?api=1&query=';

  // ---- Networking / timing ----
  static const Duration apiConnectTimeout = Duration(seconds: 15);
  static const Duration apiReceiveTimeout = Duration(seconds: 30);

  /// How long an idle socket is kept alive (Dart's default is 15s), so moving
  /// between screens reuses the connection instead of re-negotiating TLS.
  ///
  /// The socket *count* is deliberately left unbounded — see [ApiClient].
  static const Duration apiIdleTimeout = Duration(seconds: 30);

  /// How recent a presence ping must be for an employee to count as "online"
  /// on the nearby radar.
  static const Duration nearbyOnlineWindow = Duration(minutes: 5);

  /// GPS-search radius slider bounds (meters) on the nearby map.
  static const double nearbyRadiusMinMeters = 5.0;
  static const double nearbyRadiusMaxMeters = 200.0;

  // ---- Visit scheduling ----
  /// How far ahead / back a visit may be scheduled in the date picker.
  static const Duration visitScheduleMaxAhead = Duration(days: 365);
  static const Duration visitSchedulePastGrace = Duration(days: 1);

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

  /// Standard Odoo models the app reads generically.
  static const String attachmentModel = 'ir.attachment';
  static const String mailActivityModel = 'mail.activity';
  static const String partnerCategoryModel = 'res.partner.category';

  // ---- dh_visit_management security groups (res.groups) ----
  // The logged-in user's visit role is derived by matching their `group_ids`
  // against these (highest wins). See AuthUser.visitRole.
  //
  // Odoo assigns `res.groups` row ids at install time, so they differ per
  // database — and every company points the app at its own Odoo. The ids are
  // therefore resolved from these xmlids at login (see VisitGroupIds.resolve);
  // only the module + record names below are stable across servers.
  static const String visitGroupModule = 'dh_visit_management';
  static const String groupVisitUserXmlName = 'group_visit_user';
  static const String groupVisitManagerXmlName = 'group_visit_manager';
  static const String groupVisitProjectManagerXmlName =
      'group_visit_project_manager';
  static const String groupVisitAdminXmlName = 'group_visit_admin';

  // Attendance: the salesperson's check-in / check-out is also mirrored to
  // Odoo's standard `hr.attendance` (with GPS in the native `in_*` / `out_*`
  // fields) so it shows up in the Attendances module. Each app user is matched
  // to an `hr.employee` via its `user_id`.
  static const String hrAttendanceModel = 'hr.attendance';
  static const String hrEmployeeModel = 'hr.employee';
}
