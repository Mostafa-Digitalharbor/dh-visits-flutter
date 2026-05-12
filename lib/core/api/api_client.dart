import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';

import '../constants.dart';
import 'api_exceptions.dart';
import 'pretty_log_interceptor.dart';

class ApiClient {
  late final Dio dio;
  final PersistCookieJar cookieJar;

  final _unauthorizedController = StreamController<void>.broadcast();

  /// Fires whenever the server rejects a request as unauthorized
  /// (HTTP 401/403 or `AUTH_REQUIRED`). Listen once from the app shell to
  /// trigger an automatic logout.
  Stream<void> get onUnauthorized => _unauthorizedController.stream;

  ApiClient({required this.cookieJar}) {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        contentType: 'application/json',
        responseType: ResponseType.json,
        headers: {
          'Accept': 'application/json',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    dio.interceptors.add(CookieManager(cookieJar));

    if (kDebugMode) {
      dio.interceptors.add(PrettyLogInterceptor());
    }
  }

  /// Odoo JSON-RPC call.
  Future<dynamic> jsonRpc(
    String path, {
    Map<String, dynamic>? params,
  }) async {
    debugPrint('[debug] ApiClient.jsonRpc -> POST $path');
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
      debugPrint('[debug] ApiClient.jsonRpc <- status=${response.statusCode} '
          'bodyType=${body.runtimeType}');
      if (body is Map && body['error'] != null) {
        debugPrint('[debug] ApiClient.jsonRpc Odoo error block: ${body['error']}');
        throw ApiException.fromJson(Map<String, dynamic>.from(body));
      }
      return body is Map ? body['result'] : body;
    } on DioException catch (e) {
      debugPrint('[debug] ApiClient.jsonRpc DioException: ${e.type} ${e.message}');
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
      return _unwrap(response);
    } on DioException catch (e) {
      throw _mapDioError(e);
    } on ApiException catch (e) {
      _notifyIfUnauthorized(e);
      rethrow;
    }
  }

  dynamic _unwrap(Response response) {
    final body = response.data;
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw ApiException.unauthorized();
    }
    // Odoo returns the website HTML (200 OK) for any path it doesn't have a
    // route for. Catch that here so the caller sees "endpoint missing"
    // instead of silently treating it as empty data.
    if (body is String && body.trimLeft().startsWith('<')) {
      throw ApiException(
        code: ApiErrorCode.notFound,
        serverMessage:
            'Endpoint ${response.realUri.path} is not deployed on the backend.',
      );
    }
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
        break;
      case DioExceptionType.connectionError:
        mapped = ApiException.network();
        break;
      default:
        mapped = ApiException.unknown(e.message);
    }
    return mapped;
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
