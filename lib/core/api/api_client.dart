import 'dart:async';
import 'dart:io' show HttpClient;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';

import '../constants.dart';
import '../network/connectivity_status.dart';
import 'api_exceptions.dart';
import 'pretty_log_interceptor.dart';

class ApiClient {
  late final Dio dio;
  final PersistCookieJar cookieJar;

  /// Tracks whether the last network call we observed succeeded.
  /// Optional so unit-test instances and feature-disabled builds keep
  /// working — `null` means "don't bother updating connectivity".
  final ConnectivityStatus? connectivity;

  final _unauthorizedController = StreamController<void>.broadcast();

  /// Fires whenever the server rejects a request as unauthorized
  /// (HTTP 401/403 or `AUTH_REQUIRED`). Listen once from the app shell to
  /// trigger an automatic logout.
  Stream<void> get onUnauthorized => _unauthorizedController.stream;

  ApiClient({
    required this.cookieJar,
    this.connectivity,
    String baseUrl = '',
  }) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: AppConstants.apiConnectTimeout,
        receiveTimeout: AppConstants.apiReceiveTimeout,
        contentType: 'application/json',
        responseType: ResponseType.json,
        headers: {
          'Accept': 'application/json',
        },
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
  Future<dynamic> jsonRpc(
    String path, {
    Map<String, dynamic>? params,
  }) async {
    // Request/response tracing is deliberately left to PrettyLogInterceptor,
    // which is registered only under kDebugMode. `debugPrint` is NOT stripped
    // from release builds, so logging bodies here would ship session cookies
    // and record payloads to the device log on every user's phone.
    try {
      final response = await dio.post(
        path,
        data: {
          'jsonrpc': '2.0',
          'method': 'call',
          'params': params ?? {},
        },
      );

      final body = response.data;
      // Got a response from the server — we're online, even if the
      // response itself is a server-side error.
      connectivity?.markOnline();
      // Odoo's own error block first: it carries a real message, which beats
      // the generic transport codes below.
      if (body is Map && body['error'] != null) {
        throw ApiException.fromJson(Map<String, dynamic>.from(body));
      }
      // Then the same transport guards `_unwrap` applies to get/post. This call
      // used to skip them entirely and hand `body['result']` straight back, so
      // an un-deployed `/api/visit/*` route (Odoo answers 200 + website HTML)
      // arrived as a String, callers degraded it to "no visits", and a 403
      // never reached `onUnauthorized` so the auto-logout never fired.
      _guardTransport(response);
      return body is Map ? body['result'] : body;
    } on DioException catch (e) {
      throw _mapDioError(e);
    } on ApiException catch (e) {
      _notifyIfUnauthorized(e);
      rethrow;
    }
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response =
          await dio.get(path, queryParameters: queryParameters);
      connectivity?.markOnline();
      return _unwrap(response);
    } on DioException catch (e) {
      throw _mapDioError(e);
    } on ApiException catch (e) {
      _notifyIfUnauthorized(e);
      rethrow;
    }
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await dio.post(path, data: data);
      connectivity?.markOnline();
      return _unwrap(response);
    } on DioException catch (e) {
      throw _mapDioError(e);
    } on ApiException catch (e) {
      _notifyIfUnauthorized(e);
      rethrow;
    }
  }

  /// Transport-level checks that apply to every response regardless of which
  /// envelope (JSON-RPC or REST) the body uses. Shared by [jsonRpc] and
  /// [_unwrap] so neither can drift into trusting a body the other rejects.
  void _guardTransport(Response response) {
    final body = response.data;
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw ApiException.unauthorized();
    }
    // Odoo returns the website HTML (200 OK) for any path it doesn't have a
    // route for. Catch that here so the caller sees "endpoint missing"
    // instead of silently treating it as empty data.
    //
    // The path goes in `details`, not `serverMessage`: `localize()` renders
    // serverMessage verbatim, which would put an English sentence on an
    // Arabic screen. The localized `errEndpointMissing` explains it instead.
    // `notSupported`, not `notFound`: a missing route means the custom visits
    // module isn't installed on this server, and "item not found" would send
    // the admin looking for a missing record instead of a missing module.
    if (body is String && body.trimLeft().startsWith('<')) {
      throw ApiException(
        code: ApiErrorCode.notSupported,
        details: 'Endpoint ${response.realUri.path} is not deployed.',
      );
    }
    // `validateStatus` lets everything under 500 through, so an error status
    // with a non-Odoo body would otherwise be handed to the caller as if it
    // were successful data — surfacing later as a confusing parse failure
    // instead of a real message.
    final status = response.statusCode ?? 0;
    if (status >= 400) {
      if (body is Map && body['status'] == 'error') {
        throw ApiException.fromJson(Map<String, dynamic>.from(body));
      }
      throw ApiException(
        code: switch (status) {
          404 => ApiErrorCode.notFound,
          409 => ApiErrorCode.conflict,
          422 => ApiErrorCode.validation,
          >= 500 => ApiErrorCode.server,
          _ => ApiErrorCode.unknown,
        },
        details: 'HTTP $status for ${response.realUri.path}',
      );
    }
  }

  dynamic _unwrap(Response response) {
    _guardTransport(response);
    final body = response.data;
    if (body is Map) {
      if (body['status'] == 'error') {
        throw ApiException.fromJson(Map<String, dynamic>.from(body));
      }
      return body['data'] ?? body;
    }
    return body;
  }

  ApiException _mapDioError(DioException e) {
    ApiException mapped;
    if (e.response != null && e.response!.data is Map) {
      try {
        mapped = ApiException.fromJson(
            Map<String, dynamic>.from(e.response!.data));
        _notifyIfUnauthorized(mapped);
        return mapped;
      } catch (_) {}
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        mapped = ApiException.timeout();
        connectivity?.markOffline();
        break;
      case DioExceptionType.badCertificate:
        mapped = ApiException(
          code: ApiErrorCode.insecureConnection,
          details: e.message,
        );
        break;
      case DioExceptionType.connectionError:
        // A rejected certificate can also arrive as a connectionError wrapping
        // a HandshakeException. Telling the admin to "check your internet"
        // there sends them hunting the wrong problem.
        mapped = _isTlsFailure(e)
            ? ApiException(
                code: ApiErrorCode.insecureConnection,
                details: e.message,
              )
            : ApiException.network();
        if (mapped.code == ApiErrorCode.network) connectivity?.markOffline();
        break;
      case DioExceptionType.badResponse:
        // `validateStatus` rejects >= 500, so 5xx lands here rather than in
        // `_unwrap`. Without this arm it fell through to `unknown` and the
        // user read "an unknown error occurred" for a plain server outage.
        final status = e.response?.statusCode ?? 0;
        mapped = ApiException(
          code: status >= 500 ? ApiErrorCode.server : ApiErrorCode.unknown,
          details: 'HTTP $status',
        );
        break;
      default:
        // `e.message` is Dio's own diagnostic ("Connection closed before full
        // header was received") — technical, English, and not something to
        // put in front of a user. Keep it for logs only.
        mapped = ApiException.unexpected(e.message);
    }
    return mapped;
  }

  /// A TLS/certificate failure hiding inside a generic connection error —
  /// typical for a self-signed certificate on an on-premise Odoo, which is the
  /// most likely first-run failure on the server-setup screen.
  static bool _isTlsFailure(DioException e) {
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
