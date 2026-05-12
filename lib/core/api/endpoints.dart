class Endpoints {
  Endpoints._();

  // Auth (Odoo built-in JSON-RPC)
  static const String authenticate = '/web/session/authenticate';
  static const String destroySession = '/web/session/destroy';
  static const String sessionInfo = '/web/session/get_session_info';

  // Custom REST endpoints (provided by Odoo developer)
  static const String customers = '/api/customers';
  static String customerById(int id) => '/api/customers/$id';
  static String nearbyEmployees(int customerId) =>
      '/api/customers/$customerId/nearby-employees';

  static const String checkIn = '/api/visits/check-in';
  static const String checkOut = '/api/visits/check-out';
  static const String visits = '/api/visits';

  static const String updateEmployeeLocation = '/api/employee/location';
}
