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
}
