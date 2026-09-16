import 'config/app_environment.dart';

export 'constants/app_locales.dart';
export 'constants/storage_keys.dart';
export 'constants/ui_keys.dart';

class AppConstants {
  AppConstants._();

  /// Backend base URL. Sourced from `--dart-define=API_BASE_URL=...`.
  /// See [AppEnvironment] for build-flavor overrides.
  static String get baseUrl => AppEnvironment.baseUrl;

  /// Odoo database name. Sourced from `--dart-define=ODOO_DATABASE=...`.
  static String get database => AppEnvironment.database;

  // ---- Visit GPS trail ----
  // The path recorded between a visit's Start and End — and only then. The
  // native capture (VisitLocationService / VisitLocation.swift) applies the
  // sampling rules; the foreground-stream fallback applies the same ones.
  // Dense enough that a drawn trail follows the road and its turns, sparse
  // enough that standing still records nothing.

  /// Minimum movement between two recorded fixes. Below it a fix is standing
  /// still (or GPS jitter), not movement. Also the OS `distanceFilter`.
  static const double trailMinDistanceMeters = 10.0;

  /// Minimum time between two recorded fixes, unless the second already covers
  /// [trailBurstDistanceMeters]. Just under the native 5 s request interval, so
  /// delivery jitter never skips a sample.
  static const Duration trailMinInterval = Duration(seconds: 4);

  /// A fix inside [trailMinInterval] is still kept when it is this far away.
  /// Mirrors `BURST_DISTANCE_M` in VisitLocationService.
  static const double trailBurstDistanceMeters = 15.0;

  /// A fix less certain than this is discarded rather than drawn: it would put
  /// a vertex off the real street and inflate the server's
  /// `tracked_distance_km` along with it. (The native capture relaxes this to
  /// 100 m after 30 s without a usable fix, so an urban canyon leaves a coarse
  /// point instead of a gap.)
  static const double trailMaxAccuracyMeters = 50.0;

  /// How often fixes recorded by the native capture are moved into the upload
  /// buffer while the app process is alive (foreground or background).
  static const Duration trailDrainInterval = Duration(seconds: 15);

  /// How often the buffered fixes are pushed to the server.
  static const Duration trailFlushInterval = Duration(minutes: 1);

  /// Buffer size that triggers an immediate flush without waiting for the timer.
  static const int trailFlushBatchSize = 20;

  /// Upper bound on one `log_locations` call, so a long offline stretch uploads
  /// across several requests instead of one that times out.
  static const int trailMaxBatchSize = 100;

  /// Most fixes moved from the native journal in one drain.
  static const int trailMaxDrain = 500;

  /// Hard ceiling on the on-device buffer (several hours of continuous
  /// movement offline at the sampling rate above). Past this the oldest fixes
  /// are dropped: the recent path is the part still worth uploading.
  static const int trailMaxBufferedPoints = 4000;

  /// How many times a batch the server *refuses* is retried before its points
  /// are abandoned, so a genuinely impossible point is not retried forever.
  static const int trailMaxFlushAttempts = 5;

  /// Visits whose local end time is remembered (to drop any fix recorded after
  /// it). Older entries are forgotten first.
  static const int trailMaxEndedVisits = 20;

  /// Shortest gap between two server checks that a visit being recorded is
  /// still in progress (on app resume, after a refused batch).
  static const Duration trailVerifyInterval = Duration(seconds: 30);

  /// How often an open trail screen re-reads a visit that is still running.
  static const Duration trailLiveRefreshInterval = Duration(seconds: 30);

  static const double defaultMapZoom = 19.0;

  // ---- Map tiles (OpenStreetMap) ----
  // Shared by every map in the app via [AppMapTileLayer] so tiles render
  // identically everywhere. Change the provider in one place here.
  static const String mapTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Must be the app's real package id (`applicationId` / bundle id): the
  /// OSM tile policy requires an identifying user agent, and OSRM sees it too.
  static const String mapUserAgent = 'net.digitalharbor.visits';

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

  /// Longest a request body may take to go out. Without it a stalled upload
  /// hangs until the OS gives up on the socket, minutes later.
  static const Duration apiSendTimeout = Duration(seconds: 30);

  /// Send and receive limit for file uploads (`Endpoints.uploads`): a photo
  /// on a weak link, then stored server-side, needs far longer than JSON.
  static const Duration apiUploadTimeout = Duration(minutes: 3);

  /// How long an idle socket is kept alive (Dart's default is 15s), so moving
  /// between screens reuses the connection instead of re-negotiating TLS.
  ///
  /// The socket *count* is deliberately left unbounded — see [ApiClient].
  static const Duration apiIdleTimeout = Duration(seconds: 30);

  /// Longest a pull-to-refresh spinner waits for its reload before letting go.
  /// The reload keeps running; only the gesture stops blocking.
  static const Duration refreshTimeout = Duration(seconds: 30);

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

  /// Employees (the participant picker, the signed-in user's employee).
  static const String hrEmployeeModel = 'hr.employee';

  /// Chatter messages (a record's history and notes).
  static const String mailMessageModel = 'mail.message';

  // ---- Offline visit actions (PendingActionsQueue) ----

  /// How often queued Start / End actions are retried while the app runs, on
  /// top of the retry that fires when connectivity comes back.
  static const Duration pendingActionFlushInterval = Duration(seconds: 60);

  /// Failed replays (other than plain connectivity failures) after which a
  /// queued action is given up and the user told. Keeps one broken action from
  /// holding the rest of the queue forever.
  static const int pendingActionMaxAttempts = 8;

  /// Age after which a queued action that still can't be replayed is given up.
  /// Two weeks covers any realistic stretch without coverage.
  static const Duration pendingActionMaxAge = Duration(days: 14);

  /// Rows fetched for a searchable directory (customers, the employee picker).
  /// Both lists are searched server-side, so a page is a starting view, not
  /// the whole directory — the search field reaches everything else.
  static const int directoryPageLimit = 50;
}
