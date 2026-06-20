import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../api/api_exceptions.dart';

/// Forwards every unhandled BLoC error to Sentry so we don't have to
/// sprinkle `Sentry.captureException(...)` inside every `catch (e)` branch.
///
/// Expected failure modes (no network, server-side validation, expired
/// session) are filtered out -- those are normal user-facing UX, not crashes
/// worth alerting on. Anything else (parsing errors, null derefs, plugin
/// failures) is reported with the bloc class name as a tag so we can find
/// hot-spots quickly.
class SentryBlocObserver extends BlocObserver {
  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);

    if (_isExpected(error)) return;

    Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.setTag('bloc', bloc.runtimeType.toString());
      },
    );

    if (kDebugMode) {
      // Mirror to console so devs see it locally without opening Sentry.
      debugPrint('[Sentry/Bloc] ${bloc.runtimeType}: $error');
    }
  }

  bool _isExpected(Object error) {
    if (error is! ApiException) return false;
    switch (error.code) {
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
        return true;
      case ApiErrorCode.server:
      case ApiErrorCode.customerLoadFailed:
      case ApiErrorCode.unknown:
        return false;
    }
  }
}
