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

  /// The feature isn't supported by the connected Odoo server. Used for
  /// capabilities (live employee location / nearby map) that have no
  /// storage in a vanilla Odoo without the custom visits module.
  notSupported,

  /// The stored session could not be read back on startup (corrupted keystore
  /// after a device restore, or a changed payload shape). The user simply
  /// needs to sign in again.
  sessionRestoreFailed,

  /// The request collided with the record's current state — e.g. the visit was
  /// already started from another device. Retrying the same call won't help;
  /// the user must reload and look at the new state.
  conflict,

  /// A secure connection could not be established: an untrusted or expired
  /// TLS certificate. Distinct from [network] because "check your internet"
  /// is the wrong advice — the address is reachable, the certificate isn't
  /// trusted.
  insecureConnection,
  unknown,
}

class ApiException implements Exception {
  final ApiErrorCode code;

  /// A human-readable message *produced by the server* (an Odoo `UserError`
  /// / `ValidationError` body, say) — meaningful enough to show verbatim,
  /// which `ApiExceptionL10n.localize` does for the codes that carry one.
  ///
  /// Never put a raw Dart/Dio exception string here: it would be rendered to
  /// the user untranslated. Use [ApiException.unexpected] instead, which
  /// routes the diagnostic to [details].
  final String? serverMessage;

  /// Diagnostic payload for logs and Sentry. Never rendered to the user.
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

  /// An unexpected failure that carries no server-authored message: a JSON
  /// parse error, a null cast, a plugin throw, an unclassified Dio failure.
  ///
  /// The raw text is kept in [details] for Sentry and deliberately kept out
  /// of [serverMessage] — otherwise `localize()` shows it verbatim and the
  /// user reads "type 'Null' is not a subtype of type 'String'" in the
  /// middle of an Arabic screen. They get the generic localized fallback
  /// instead, while the diagnostic still reaches the logs.
  factory ApiException.unexpected(Object? error) =>
      ApiException(code: ApiErrorCode.unknown, details: error?.toString());

  /// Restoring the persisted session threw. Like [unexpected], the raw text
  /// stays in [details] so the user reads a localized sentence instead of a
  /// platform exception.
  factory ApiException.sessionRestoreFailed(Object? error) => ApiException(
        code: ApiErrorCode.sessionRestoreFailed,
        details: error?.toString(),
      );

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

  /// Includes [details] because this is what Sentry serializes for an
  /// unhandled bloc error, and for `unexpected` errors the diagnostic lives
  /// there rather than in [serverMessage].
  @override
  String toString() {
    final parts = [
      if (serverMessage != null) serverMessage,
      if (details != null) 'details: $details',
    ];
    return parts.isEmpty
        ? 'ApiException($code)'
        : 'ApiException($code, ${parts.join(', ')})';
  }
}
