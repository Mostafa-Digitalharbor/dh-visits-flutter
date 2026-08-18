import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../utils/app_log.dart';
import 'sentry_noise_filter.dart';

/// Forwards every unhandled BLoC error to Sentry so we don't have to
/// sprinkle `Sentry.captureException(...)` inside every `catch (e)` branch.
///
/// Expected failure modes (no network, server-side validation, expired
/// session) are filtered out by [isSentryNoise] -- those are normal
/// user-facing UX, not crashes worth alerting on. Anything else (parsing
/// errors, null derefs, plugin failures) is reported with the bloc class name
/// as a tag so we can find hot-spots quickly.
///
/// The same predicate also runs in `SentryOptions.beforeSend`, which catches
/// the errors that never pass through a bloc (zone errors, plugin callbacks).
/// Keeping one predicate means the two paths can't drift apart.
class SentryBlocObserver extends BlocObserver {
  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);

    if (isSentryNoise(error)) return;

    Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.setTag('bloc', bloc.runtimeType.toString());
      },
    );

    if (kDebugMode) {
      // Mirror to console so devs see it locally without opening Sentry.
      appLog('[Sentry/Bloc] ${bloc.runtimeType}: $error');
    }
  }
}
