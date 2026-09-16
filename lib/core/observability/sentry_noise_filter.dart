import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../api/api_exceptions.dart';

/// Whether [error] is *environmental noise* rather than a defect in the app.
///
/// A phone in a lift, an expired session, a customer's Odoo returning 403 for a
/// user without the right group — none of those are bugs. They are already
/// handled and shown to the user as a normal message. Reporting them would bury
/// the real crashes under thousands of duplicates and burn the free Sentry
/// quota inside a week, which is exactly what happened before this filter
/// existed.
///
/// Deliberately **not** filtered: 5xx (the server really did break),
/// [ApiErrorCode.unknown] (an unmapped shape — that is the interesting case),
/// and anything that isn't recognisably a network failure.
bool isSentryNoise(Object? error) {
  if (error == null) return false;

  if (error is ApiException) return _isExpectedApiCode(error.code);

  if (error is DioException) return _isNoisyDioError(error);

  // Raw transport failures that never went through [ApiClient] — image upload
  // streams, attachment downloads, the FCM token fetch.
  if (error is SocketException ||
      error is HandshakeException ||
      error is TlsException ||
      error is TimeoutException) {
    return true;
  }

  return false;
}

bool _isNoisyDioError(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
    case DioExceptionType.badCertificate:
    case DioExceptionType.cancel:
      return true;
    case DioExceptionType.badResponse:
      // 4xx is the client/session/permission family — the app's own error
      // messages already cover it. 5xx stays reportable.
      final status = e.response?.statusCode ?? 0;
      return status >= 400 && status < 500;
    case DioExceptionType.unknown:
      return isSentryNoise(e.error);
  }
}

bool _isExpectedApiCode(ApiErrorCode code) {
  switch (code) {
    case ApiErrorCode.network:
    case ApiErrorCode.timeout:
    case ApiErrorCode.unauthorized:
    case ApiErrorCode.invalidCredentials:
    case ApiErrorCode.permissionDenied:
    case ApiErrorCode.validation:
    case ApiErrorCode.locationPermission:
    case ApiErrorCode.locationRequired:
    case ApiErrorCode.notFound:
    case ApiErrorCode.notSupported:
    // Environmental, not a defect: an expired session, a rejected TLS
    // certificate, or two devices racing on the same visit.
    case ApiErrorCode.sessionRestoreFailed:
    case ApiErrorCode.insecureConnection:
    case ApiErrorCode.conflict:
    // An outage, throttling or a mistyped database: the server's state or the
    // user's input, which the localized message already explains.
    case ApiErrorCode.serverUnavailable:
    case ApiErrorCode.rateLimited:
    case ApiErrorCode.payloadTooLarge:
    case ApiErrorCode.databaseNotFound:
      return true;
    case ApiErrorCode.server:
    // A body the app cannot parse is either a proxy in the way or a contract
    // drift on the server — the second is exactly what Sentry is for.
    case ApiErrorCode.invalidResponse:
    case ApiErrorCode.unknown:
      return false;
  }
}
