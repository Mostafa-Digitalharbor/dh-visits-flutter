class Endpoints {
  Endpoints._();

  // Auth (Odoo built-in JSON-RPC) — works on any vanilla Odoo.
  static const String authenticate = '/web/session/authenticate';
  static const String destroySession = '/web/session/destroy';
  static const String sessionInfo = '/web/session/get_session_info';

  /// Lists the databases exposed by an Odoo server. Only works when the
  /// server has `list_db` enabled (single-tenant / on-prem instances). Used to
  /// auto-detect the database during server setup.
  static const String databaseList = '/web/database/list';

  /// Odoo's generic ORM-over-JSON-RPC endpoint. Everything the app does
  /// (read customers, create/read visits, etc.) goes through `call_kw` on
  /// standard models — no custom REST controllers required on the server.
  static const String callKw = '/web/dataset/call_kw';

  /// Odoo's built-in attendance toggle (the same route the web "systray"
  /// check-in/out button uses). Runs server-side with elevated rights, so a
  /// regular employee can clock themselves in/out even though they can't
  /// `create` an `hr.attendance` row directly. Accepts `{latitude, longitude}`
  /// and records them in the native `in_/out_latitude/longitude` fields.
  /// Toggles state: returns `attendance_state` = 'checked_in' | 'checked_out'.
  static const String attendanceSystray = '/hr_attendance/systray_check_in_out';

  // ---- dh_visit_management mobile REST API (JSON-RPC `type='json'`) --------
  // Dedicated controllers for the visit approval workflow. All are POST with
  // the JSON-RPC envelope; auth is the same session cookie as the rest of the
  // app. See docs/VISITS_API.md.
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
}
