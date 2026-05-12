enum ApiErrorCode {
  network,
  timeout,
  unauthorized,
  invalidCredentials,
  permissionDenied,
  validation,
  notFound,
  locationRequired,
  server,
  locationPermission,
  customerLoadFailed,
  unknown,
}

class ApiException implements Exception {
  final ApiErrorCode code;
  final String? serverMessage;
  final dynamic details;

  ApiException({
    required this.code,
    this.serverMessage,
    this.details,
  });

  factory ApiException.fromJson(Map<String, dynamic> json) {
    final err = json['error'] is Map ? json['error'] as Map<String, dynamic> : json;
    final rawCode = (err['code'] ?? '').toString();

    // Odoo JSON-RPC error shape:
    //   error: { code: 200, message: "Odoo Server Error",
    //            data: { name, message, debug, arguments } }
    final data = err['data'] is Map ? err['data'] as Map : null;
    final dataMessage = data?['message']?.toString();
    final dataName = data?['name']?.toString();

    // Prefer the inner Odoo message ("data.message") over the wrapper
    // ("error.message") since the wrapper is always "Odoo Server Error".
    String? serverMessage =
        dataMessage?.isNotEmpty == true ? dataMessage : null;
    serverMessage ??= err['message']?.toString();

    return ApiException(
      code: _mapCode(rawCode, dataName, serverMessage),
      serverMessage: serverMessage,
      details: err['details'] ?? err['data'],
    );
  }

  factory ApiException.network() => ApiException(code: ApiErrorCode.network);

  factory ApiException.timeout() => ApiException(code: ApiErrorCode.timeout);

  factory ApiException.unauthorized() =>
      ApiException(code: ApiErrorCode.unauthorized);

  factory ApiException.unknown(String? message) =>
      ApiException(code: ApiErrorCode.unknown, serverMessage: message);

  static ApiErrorCode _mapCode(
    String raw, [
    String? odooName,
    String? message,
  ]) {
    switch (raw) {
      case 'AUTH_REQUIRED':
        // The addon's REST controllers sometimes leak field-level access
        // errors back as AUTH_REQUIRED (e.g. trying to read
        // `current_latitude / location_sharing` from an employee's
        // public profile). That's a permission problem, not a session
        // expiry — classify it as permissionDenied so the app doesn't
        // log the user out.
        if (_looksLikeFieldPermissionError(message)) {
          return ApiErrorCode.permissionDenied;
        }
        return ApiErrorCode.unauthorized;
      case 'INVALID_CREDENTIALS':
        return ApiErrorCode.invalidCredentials;
      case 'PERMISSION_DENIED':
        return ApiErrorCode.permissionDenied;
      case 'VALIDATION_ERROR':
        return ApiErrorCode.validation;
      case 'NOT_FOUND':
        return ApiErrorCode.notFound;
      case 'LOCATION_REQUIRED':
        return ApiErrorCode.locationRequired;
      case 'SERVER_ERROR':
        return ApiErrorCode.server;
      case 'NETWORK_ERROR':
        return ApiErrorCode.network;
    }
    // Odoo JSON-RPC errors carry a Python exception name (e.g.
    // "odoo.exceptions.AccessDenied"). Treat the well-known ones.
    switch (odooName) {
      case 'odoo.http.SessionExpiredException':
        return ApiErrorCode.unauthorized;
      case 'odoo.exceptions.AccessDenied':
        return ApiErrorCode.invalidCredentials;
      case 'odoo.exceptions.AccessError':
        return ApiErrorCode.permissionDenied;
      case 'odoo.exceptions.UserError':
      case 'odoo.exceptions.ValidationError':
        return ApiErrorCode.validation;
      case 'odoo.exceptions.MissingError':
        return ApiErrorCode.notFound;
    }
    return ApiErrorCode.unknown;
  }

  static bool _looksLikeFieldPermissionError(String? message) {
    if (message == null) return false;
    final lc = message.toLowerCase();
    return lc.contains('not available for') ||
        lc.contains('public profile') ||
        (lc.contains('fields') &&
            (lc.contains('not available') ||
                lc.contains('which you are trying to read')));
  }

  @override
  String toString() => 'ApiException($code, $serverMessage)';
}
