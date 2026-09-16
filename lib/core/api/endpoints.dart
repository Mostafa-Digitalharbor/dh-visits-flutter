class Endpoints {
  Endpoints._();

  // Auth (Odoo built-in JSON-RPC) — works on any vanilla Odoo.
  static const String authenticate = '/web/session/authenticate';
  static const String destroySession = '/web/session/destroy';

  /// The server's version. Public (no session needed) and tiny, which makes it
  /// the reachability probe while the app believes it is offline.
  static const String versionInfo = '/web/webclient/version_info';

  /// Lists the databases exposed by an Odoo server. Only works when the
  /// server has `list_db` enabled (single-tenant / on-prem instances). Used to
  /// auto-detect the database during server setup.
  static const String databaseList = '/web/database/list';

  /// Odoo's generic ORM-over-JSON-RPC endpoint. Everything the app does
  /// (read customers, create/read visits, etc.) goes through `call_kw` on
  /// standard models — no custom REST controllers required on the server.
  static const String callKw = '/web/dataset/call_kw';

  // ---- dh_visit_management mobile REST API (JSON-RPC `type='json'`) --------
  // Dedicated controllers for the visit approval workflow. All are POST with
  // the JSON-RPC envelope; auth is the same session cookie as the rest of the
  // app. The contract is docs/API.md.
  static const String visitMy = '/api/visit/my';
  static const String visitGet = '/api/visit/get';
  static const String visitCreate = '/api/visit/create';
  static const String visitSubmit = '/api/visit/submit';
  static const String visitApprove = '/api/visit/approve';
  static const String visitReject = '/api/visit/reject';
  static const String visitReschedule = '/api/visit/reschedule';
  static const String visitAddParticipants = '/api/visit/add_participants';
  static const String visitStart = '/api/visit/start';
  static const String visitEnd = '/api/visit/end';
  static const String visitUploadAttachment = '/api/visit/upload_attachment';

  // Attendee (track-2) approval. The participant lines are also actionable via
  // `call_kw` on `dh.visit.participant`, which is what this app used before the
  // module exposed these routes; `VisitsRepository` still falls back to that
  // path when a server predates them.
  static const String visitAttendeeApprove = '/api/visit/attendee/approve';
  static const String visitAttendeeReject = '/api/visit/attendee/reject';

  // ---- GPS trail (append-only path between start and end) -----------------
  // `log_location` posts a single fix; `log_locations` flushes a buffer in one
  // round trip and reports malformed points individually (by their index in the
  // request) so one bad fix never costs the rest of the queue. `track` reads the
  // trail back, always oldest-first, ready to feed straight into a polyline.
  static const String visitLogLocation = '/api/visit/log_location';
  static const String visitLogLocations = '/api/visit/log_locations';
  static const String visitTrack = '/api/visit/track';

  // ---- Push notifications (device token registration) ---------------------
  // The app registers its FCM token after login so the backend can push visit
  // workflow events. See docs/BACKEND_PUSH_NOTIFICATIONS.md.
  static const String registerDevice = '/api/visit/register_device';
  static const String unregisterDevice = '/api/visit/unregister_device';

  /// Routes that carry a file. They get [AppConstants.apiUploadTimeout]
  /// instead of the default timeouts: a photo over a weak mobile link takes
  /// far longer to send, and the server longer to store, than a JSON call.
  static const Set<String> uploads = {visitUploadAttachment};

  /// Odoo's sign-in page. A request that ends up here was bounced by an
  /// expired session, whatever the route it was sent to.
  static const String loginPage = '/web/login';

  /// Prefix of Odoo's core routes, which exist on every Odoo.
  static const String coreRoutePrefix = '/web/';
}
