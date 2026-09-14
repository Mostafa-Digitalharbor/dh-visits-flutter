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

  /// The Odoo exception class from `error.data.name`
  /// (`odoo.exceptions.UserError`, `odoo.http.SessionExpiredException`, …).
  /// docs/API.md is explicit that this — not `error.code`, which is `0` for a
  /// `UserError` and `100` for an expiry — is what to branch on.
  final String? odooName;

  ApiException({
    required this.code,
    this.serverMessage,
    this.details,
    this.odooName,
  });

  /// The session cookie is no longer valid. The one Odoo failure a client may
  /// retry: re-authenticate, then repeat the call once (see `ApiClient`).
  bool get isSessionExpired =>
      odooName == 'odoo.http.SessionExpiredException';

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
    String? rawMessage =
        dataMessage?.isNotEmpty == true ? dataMessage : null;
    rawMessage ??= err['message']?.toString();

    // Classify *before* deciding what the user may see: the code mapping still
    // wants the raw text (it sniffs field-permission errors out of
    // AUTH_REQUIRED), but only messages a human actually authored are fit to
    // render.
    final code = _mapCode(rawCode, dataName, rawMessage);
    final showable = _isUserFacingMessage(dataName, rawMessage);

    return ApiException(
      code: code,
      serverMessage: showable ? rawMessage : null,
      // The diagnostic is never lost — it just moves somewhere the UI can't
      // render it from.
      details: err['details'] ?? err['data'] ?? (showable ? null : rawMessage),
      odooName: dataName,
    );
  }

  /// Odoo exception classes whose `data.message` is written *for an end user*.
  ///
  /// `UserError` / `ValidationError` / `RedirectWarning` are what an Odoo
  /// developer raises to explain a business rule ("A visit cannot be started
  /// before its scheduled time"). Everything else — `builtins.TypeError`,
  /// `KeyError`, `psycopg2.*`, and even `MissingError` — carries a Python
  /// diagnostic.
  ///
  /// `AccessError` is included because docs/API.md says to show its message:
  /// the visit module raises it with a sentence explaining which record the
  /// user may not touch.
  static const _userAuthoredOdooErrors = {
    'odoo.exceptions.UserError',
    'odoo.exceptions.AccessError',
    'odoo.exceptions.ValidationError',
    'odoo.exceptions.RedirectWarning',
    'odoo.exceptions.Warning',
  };

  /// Whether [message] may be shown to the user verbatim.
  ///
  /// This exists because the live backend really does return
  /// `builtins.TypeError: VisitApiController.create_visit() missing 1 required
  /// positional argument: 'vals'` — which used to be rendered, in English,
  /// into the middle of an Arabic screen, as the sole explanation a field rep
  /// got for a failed action. An unmapped server fault is a bug on our side;
  /// the user gets the localized fallback and support gets the trace.
  static bool _isUserFacingMessage(String? odooName, String? message) {
    if (message == null || message.trim().isEmpty) return false;
    // The JSON-RPC wrapper's own text, present on every Odoo fault.
    if (message.trim() == 'Odoo Server Error') return false;
    // No Odoo exception class means this came from the module's own REST
    // contract (`{"error": {"code": "VALIDATION_ERROR", "message": ...}}`),
    // where the message is written for the app to display.
    if (odooName == null || odooName.isEmpty) return true;
    return _userAuthoredOdooErrors.contains(odooName);
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
