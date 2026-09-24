import 'dart:async';
import 'dart:io'
    show HttpClient, HttpException, HttpHeaders, SocketException, TlsException;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';

import '../constants.dart';
import '../network/connectivity_status.dart';
import '../network/server_clock.dart';
import '../utils/app_log.dart';
import 'api_exceptions.dart';
import 'endpoints.dart';
import 'pretty_log_interceptor.dart';

class ApiClient {
  late final Dio dio;
  final PersistCookieJar cookieJar;

  /// Tracks whether the device can reach the server. Optional so unit-test
  /// instances keep working — `null` means "don't bother updating it".
  final ConnectivityStatus? connectivity;

  /// Learns the device-vs-server clock offset from each response's `Date`
  /// header. Optional for the same reason as [connectivity].
  final ServerClock? serverClock;

  /// Signs back in after Odoo reports `SessionExpiredException`, returning
  /// whether a fresh `session_id` cookie is now in the jar. Wired in the
  /// service locator to `AuthRepository.reauthenticate`; a setter rather than a
  /// constructor argument because the auth repository itself needs this client.
  ///
  /// Null disables the retry: the expiry then surfaces straight away through
  /// [onUnauthorized].
  ///
  /// It may throw a transient [ApiException] (offline, server down): the
  /// refused call then fails with that error instead of signing the user out,
  /// and the next call tries to renew again.
  Future<bool> Function()? reauthenticate;

  /// Set when a renewal was refused (the stored credentials no longer work,
  /// or now belong to another account). Every later expiry then goes straight
  /// to sign-out instead of repeating a doomed login — which would also trip
  /// Odoo's failed-login cooldown and lock the user out of signing in by hand.
  /// Cleared by [sessionEstablished].
  bool _renewalRefused = false;

  /// A sign-in succeeded: renewals may be attempted again.
  void sessionEstablished() {
    _renewalRefused = false;
    _sessionGeneration++;
  }

  /// The re-login currently in flight, shared by every call that hit the same
  /// expired session — a screen that fans out six requests must produce one
  /// `/web/session/authenticate`, not six racing ones that overwrite each
  /// other's cookie.
  Future<bool>? _reauthInFlight;

  /// Bumped by every successful re-login. A call that was sent before the
  /// bump and comes back "expired" carried the *old* cookie: it only needs
  /// repeating, not another sign-in.
  int _sessionGeneration = 0;

  final _unauthorizedController = StreamController<void>.broadcast();

  /// Fires whenever the server rejects a request as unauthorized (HTTP 401 or
  /// `AUTH_REQUIRED`), or a session expiry could not be repaired by
  /// re-authenticating. Listen once from the app shell to trigger an automatic
  /// logout.
  Stream<void> get onUnauthorized => _unauthorizedController.stream;

  ApiClient({
    required this.cookieJar,
    this.connectivity,
    this.serverClock,
    String baseUrl = '',
  }) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: AppConstants.apiConnectTimeout,
        receiveTimeout: AppConstants.apiReceiveTimeout,
        sendTimeout: AppConstants.apiSendTimeout,
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        headers: {Headers.acceptHeader: Headers.jsonContentType},
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    // Keep idle sockets alive a little longer than Dart's 15s default, so
    // moving between screens reuses a negotiated connection instead of paying
    // for a fresh TLS handshake.
    //
    // Deliberately NOT capping `maxConnectionsPerHost`: the app fans out ~6
    // calls at cold start and letting them each open a socket is measurably
    // faster than queueing them. Benchmarked against this backend — 6 parallel
    // requests from a cold pool: ~440ms unbounded vs ~740ms capped at 2. The
    // handshakes overlap; serialising them just adds round-trips.
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.idleTimeout = AppConstants.apiIdleTimeout;
      return client;
    };

    dio.interceptors.add(CookieManager(cookieJar));

    final clock = serverClock;
    if (clock != null) {
      dio.interceptors.add(InterceptorsWrapper(
        onResponse: (response, handler) {
          clock.observeHttpDate(response.headers.value(HttpHeaders.dateHeader));
          handler.next(response);
        },
      ));
    }

    if (kDebugMode) {
      dio.interceptors.add(PrettyLogInterceptor());
    }
  }

  /// Currently active backend base URL (empty until the user configures one).
  String get baseUrl => dio.options.baseUrl;

  /// Repoints every subsequent request at [baseUrl]. Called when the user
  /// saves (or changes) their company's server on the setup screen.
  void updateBaseUrl(String baseUrl) {
    dio.options.baseUrl = baseUrl;
  }

  /// Odoo JSON-RPC call.
  ///
  /// Success and failure are decided by the body, never the status code alone:
  /// Odoo answers a refused call with HTTP 200 and an `error` block in place of
  /// `result`. When that error is `odoo.http.SessionExpiredException` the
  /// session is re-established via [reauthenticate] and the call is retried
  /// **once**; a second failure of any kind propagates.
  ///
  /// [reportUnauthorized] false is for probes that expect to be refused (the
  /// server-setup screen testing an address before anyone signs in): the
  /// failure is still thrown, but no re-login is attempted and
  /// [onUnauthorized] stays quiet, so nobody gets logged out by a probe.
  Future<dynamic> jsonRpc(
    String path, {
    Map<String, dynamic>? params,
    bool reportUnauthorized = true,
  }) =>
      _jsonRpc(
        path,
        params,
        allowReauth: reportUnauthorized,
        reportUnauthorized: reportUnauthorized,
      );

  Future<dynamic> _jsonRpc(
    String path,
    Map<String, dynamic>? params, {
    required bool allowReauth,
    required bool reportUnauthorized,
  }) async {
    final generation = _sessionGeneration;
    try {
      return await _send(path, params);
    } on ApiException catch (e) {
      if (allowReauth && e.isSessionExpired && _canReauthenticate(path)) {
        final renewed = generation != _sessionGeneration ||
            await _reauthenticateOnce();
        if (renewed) {
          appLog('[ApiClient] session renewed; retrying $path once');
          // `allowReauth: false` is what bounds this to a single retry: if the
          // fresh session is refused too, the error falls through below.
          return _jsonRpc(
            path,
            params,
            allowReauth: false,
            reportUnauthorized: reportUnauthorized,
          );
        }
      }
      if (reportUnauthorized) _notifyIfUnauthorized(e);
      rethrow;
    }
  }

  /// One round trip, turned into the `result` or an [ApiException].
  Future<dynamic> _send(String path, Map<String, dynamic>? params) async {
    // Request/response tracing is deliberately left to PrettyLogInterceptor,
    // which is registered only under kDebugMode. `debugPrint` is NOT stripped
    // from release builds, so logging bodies here would ship session cookies
    // and record payloads to the device log on every user's phone.
    final Response<dynamic> response;
    try {
      response = await dio.post<dynamic>(
        path,
        data: {
          'jsonrpc': '2.0',
          'method': 'call',
          'params': params ?? {},
        },
        options: _optionsFor(path),
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }

    final body = response.data;
    // Something answered. Whether it was Odoo is decided below; the device is
    // online either way.
    connectivity?.markOnline();
    // Odoo's own error block first: it carries a real message, which beats
    // the generic transport codes below.
    if (body is Map && body['error'] != null) {
      throw ApiException.fromJson(Map<String, dynamic>.from(body));
    }
    // An un-deployed `/api/visit/*` route arrives as website HTML, a proxy
    // error page as text; neither may be handed on as data (callers used to
    // degrade it to "no visits").
    _guardTransport(response);
    // A JSON-RPC answer is always an object. Anything else — an empty body,
    // plain text, a bare list — is not Odoo talking, and handing it on would
    // surface later as a cast error with no explanation for the user.
    // (`result` itself may be absent: Odoo 19 omits it for void methods
    // such as `/web/session/destroy`.)
    if (body is! Map) {
      throw ApiException(
        code: ApiErrorCode.invalidResponse,
        details: 'Not a JSON-RPC answer from $path: '
            '${body.runtimeType} ${_preview(body)}',
      );
    }
    return body['result'];
  }

  /// Per-route overrides of the default options.
  static Options? _optionsFor(String path) => Endpoints.uploads.contains(path)
      ? Options(
          sendTimeout: AppConstants.apiUploadTimeout,
          receiveTimeout: AppConstants.apiUploadTimeout,
        )
      : null;

  /// The auth routes themselves never trigger a re-login: an expired session
  /// on `/web/session/authenticate` means the credentials are the problem, and
  /// retrying `destroy` would sign the user straight back in on logout.
  bool _canReauthenticate(String path) =>
      reauthenticate != null &&
      !_renewalRefused &&
      path != Endpoints.authenticate &&
      path != Endpoints.destroySession;

  Future<bool> _reauthenticateOnce() {
    final running = _reauthInFlight;
    if (running != null) return running;
    final attempt = () async {
      try {
        final ok = await reauthenticate!();
        if (ok) {
          _sessionGeneration++;
        } else {
          _renewalRefused = true;
        }
        return ok;
      } on ApiException catch (e) {
        // Could not reach the server to renew: say so, keep the session.
        if (e.isTransient) rethrow;
        appLog('[ApiClient] re-authentication refused: ${e.code}');
        _renewalRefused = true;
        return false;
      } catch (e) {
        appLog('[ApiClient] re-authentication failed: $e');
        _renewalRefused = true;
        return false;
      }
    }();
    _reauthInFlight = attempt;
    // Observed here only to clear the slot: a transient failure is delivered
    // to the callers awaiting [attempt], not as an unhandled error.
    unawaited(attempt
        .then<void>((_) {}, onError: (Object _) {})
        .whenComplete(() => _reauthInFlight = null));
    return attempt;
  }

  /// Rejects a response that did not come from Odoo's JSON-RPC layer.
  ///
  /// `validateStatus` lets everything under 500 through, so without these
  /// checks an error page, a redirect or a Wi-Fi login page would be handed to
  /// the caller as if it were data.
  void _guardTransport(Response<dynamic> response) {
    final status = response.statusCode ?? 0;
    final requested = response.requestOptions.uri;
    final landed = response.realUri;
    final path = response.requestOptions.path;
    final html = _isHtml(response.data);
    final where = 'HTTP $status for $path';

    // Redirected to another host: a hotel/airport Wi-Fi login page, or an
    // address that no longer points at this company's Odoo.
    if (landed.host.isNotEmpty &&
        requested.host.isNotEmpty &&
        landed.host != requested.host) {
      throw ApiException(
        code: ApiErrorCode.invalidResponse,
        details: '$where: redirected to ${landed.host}',
      );
    }
    // Bounced to Odoo's sign-in page — how a session expiry looks on a route
    // that answers with a redirect instead of a JSON error.
    if (_isLoginPage(landed.path) && !_isLoginPage(requested.path)) {
      throw ApiException.sessionExpired('$where: redirected to sign-in');
    }
    // A redirect dart:io does not follow for POST (301/302/307/308).
    if (status >= 300 && status < 400) {
      final location = response.headers.value(HttpHeaders.locationHeader);
      final target =
          location == null ? null : requested.resolve(location.trim());
      if (target != null && _isLoginPage(target.path)) {
        throw ApiException.sessionExpired('$where: redirected to sign-in');
      }
      // Typically http → https, or a moved server: the saved address is
      // stale, which the "check the server address" message covers.
      throw ApiException(
        code: ApiErrorCode.invalidResponse,
        details: '$where: redirected to $target',
      );
    }
    if (status == 401) {
      throw ApiException(code: ApiErrorCode.unauthorized, details: where);
    }
    // Odoo reports an expired session and a refused record as JSON errors,
    // handled before this. A bare 403 comes from something in front of Odoo —
    // a firewall, a bot check — and must not sign the user out: signing back
    // in would meet the same wall and loop.
    if (status == 403) {
      throw ApiException(
        code: html ? ApiErrorCode.invalidResponse : ApiErrorCode.permissionDenied,
        details: where,
      );
    }
    // Odoo serves its website 404 page (HTML) for a route it doesn't have. On
    // the module's routes that means the visits module isn't installed —
    // `notSupported`, so the admin looks for a missing module rather than a
    // missing record. Odoo's core routes (`/web/...`) exist on every Odoo, so
    // HTML there means whatever answered is not Odoo at all.
    //
    // The path goes in `details`, not `serverMessage`: `localize()` renders
    // serverMessage verbatim, which would put English on an Arabic screen.
    if (html && (status == 404 || status < 300)) {
      throw ApiException(
        code: path.startsWith(Endpoints.coreRoutePrefix)
            ? ApiErrorCode.invalidResponse
            : ApiErrorCode.notSupported,
        details: '$where: HTML',
      );
    }
    // Any other error status: its meaning, whatever the body looks like — a
    // 413 from nginx is an HTML page, and still means "file too large". A web
    // page with a status that carries no such meaning (400, 410…) came from
    // whatever answered in Odoo's place, as on a wrong server address.
    if (status >= 400) {
      final code = _codeForStatus(status);
      throw ApiException(
        code: html && code == ApiErrorCode.unknown
            ? ApiErrorCode.invalidResponse
            : code,
        details: where,
      );
    }
  }

  static bool _isHtml(Object? body) =>
      body is String && body.trimLeft().startsWith('<');

  static bool _isLoginPage(String path) =>
      path.startsWith(Endpoints.loginPage);

  /// The meaning of an HTTP status whose body carried no Odoo error block.
  static ApiErrorCode _codeForStatus(int status) => switch (status) {
        404 => ApiErrorCode.notFound,
        // Every Odoo JSON-RPC route takes a POST, and the app only POSTs, so a
        // refused method means the server is not Odoo: example.com answers
        // exactly this.
        405 => ApiErrorCode.invalidResponse,
        // A gateway timed the request out on its own (nginx / Cloudflare).
        // Dio's own timeouts never reach here — those throw — but a 408 is a
        // real *response*, and without this it read as "unknown", which tells
        // the user to contact support about what retrying would have fixed.
        408 => ApiErrorCode.timeout,
        409 => ApiErrorCode.conflict,
        413 => ApiErrorCode.payloadTooLarge,
        422 => ApiErrorCode.validation,
        429 => ApiErrorCode.rateLimited,
        502 || 503 || 504 => ApiErrorCode.serverUnavailable,
        >= 500 => ApiErrorCode.server,
        _ => ApiErrorCode.unknown,
      };

  /// A short, log-safe sample of an unreadable body.
  static String _preview(Object? body) {
    final text = '$body'.replaceAll(RegExp(r'\s+'), ' ');
    return text.length <= _previewLength
        ? text
        : '${text.substring(0, _previewLength)}…';
  }

  static const _previewLength = 120;

  ApiException _mapDioError(DioException e) {
    final path = e.requestOptions.path;
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        // Nothing answered at all: the one timeout that says "offline".
        connectivity?.markOffline();
        return ApiException(code: ApiErrorCode.timeout, details: path);
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        // Connected, just slow — a weak link or a busy server. Flipping the
        // app to "offline" here would show a red banner on a working network.
        return ApiException(
          code: ApiErrorCode.timeout,
          details: '$path: ${e.type.name}',
        );
      case DioExceptionType.badCertificate:
        return ApiException(
          code: ApiErrorCode.insecureConnection,
          details: e.message,
        );
      case DioExceptionType.connectionError:
        // A rejected certificate can also arrive as a connectionError wrapping
        // a HandshakeException. Telling the admin to "check your internet"
        // there sends them hunting the wrong problem.
        if (_isTlsFailure(e)) {
          return ApiException(
            code: ApiErrorCode.insecureConnection,
            details: e.message,
          );
        }
        connectivity?.markOffline();
        return ApiException(
          code: ApiErrorCode.network,
          details: '$path: ${e.error ?? e.message}',
        );
      case DioExceptionType.badResponse:
        // `validateStatus` rejects >= 500, so 5xx lands here. The server
        // answered, so the device is online.
        connectivity?.markOnline();
        final status = e.response?.statusCode ?? 0;
        final data = e.response?.data;
        if (data is Map && data['error'] != null) {
          final odoo = ApiException.fromJson(Map<String, dynamic>.from(data));
          if (odoo.code != ApiErrorCode.unknown) return odoo;
          return ApiException(
            code: _codeForStatus(status),
            serverMessage: odoo.serverMessage,
            odooName: odoo.odooName,
            details: odoo.details,
          );
        }
        return ApiException(
          code: _codeForStatus(status),
          details: 'HTTP $status for $path',
        );
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        // `e.message` is Dio's own diagnostic ("Connection closed before full
        // header was received") — technical, English, and not something to
        // put in front of a user. It goes to `details` only.
        final error = e.error;
        switch (error) {
          case FormatException():
            // A body that claimed to be JSON and wasn't (or was cut short).
            return ApiException(
              code: ApiErrorCode.invalidResponse,
              details: '$path: $error',
            );
          case TlsException():
            return ApiException(
              code: ApiErrorCode.insecureConnection,
              details: '$path: $error',
            );
          case SocketException():
            // The OS lost the connection (reset, network switched, no route).
            connectivity?.markOffline();
            return ApiException(
              code: ApiErrorCode.network,
              details: '$path: $error',
            );
          case HttpException():
            // The connection dropped mid-response: a flaky mobile link, not a
            // bug, so the user is told to retry on a better connection.
            return ApiException(
              code: ApiErrorCode.network,
              details: '$path: $error',
            );
          default:
            return ApiException.unexpected('$path: ${e.message ?? error}');
        }
    }
  }

  /// A TLS/certificate failure hiding inside a generic connection error —
  /// typical for a self-signed certificate on an on-premise Odoo, which is the
  /// most likely first-run failure on the server-setup screen.
  static bool _isTlsFailure(DioException e) {
    if (e.error is TlsException) return true;
    final text = '${e.error ?? ''} ${e.message ?? ''}'.toLowerCase();
    return text.contains('handshake') ||
        text.contains('certificate') ||
        text.contains('tlsexception');
  }

  void _notifyIfUnauthorized(ApiException e) {
    if (e.code == ApiErrorCode.unauthorized) {
      _unauthorizedController.add(null);
    }
  }

  Future<void> dispose() async {
    await _unauthorizedController.close();
  }
}
