/// Central registry of every go_router path in the app.
///
/// Use the plain `static const` strings for [GoRoute.path] definitions and for
/// navigating to parameter-less screens; use the builder methods (e.g.
/// [visitDetail]) to construct paths with an id, so a route string is never
/// hand-typed at a call site.
class AppRoutes {
  AppRoutes._();

  // ---- Parameter-less routes ----
  static const String splash = '/';
  static const String setup = '/setup';
  static const String login = '/login';
  static const String home = '/home';
  static const String review = '/review';
  static const String notifications = '/notifications';
  static const String customers = '/customers';
  static const String createVisit = '/visits/create';

  // ---- Parameterized path templates (for GoRoute.path) ----
  static const String customerDetailPath = '/customers/:id';
  static const String visitDetailPath = '/visits/:id';

  /// Full-screen GPS trail of one visit. Nested under the detail path so the
  /// back gesture returns to the visit rather than to the visits list.
  static const String visitTrailPath = '/visits/:id/trail';

  // ---- Path builders (for navigation call sites) ----
  static String customerDetail(int id) => '/customers/$id';
  static String visitDetail(int id) => '/visits/$id';
  static String visitTrail(int id) => '/visits/$id/trail';
}
