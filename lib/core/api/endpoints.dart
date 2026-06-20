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
}
