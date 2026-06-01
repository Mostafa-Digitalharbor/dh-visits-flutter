import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;

import 'app/app.dart';
import 'core/config/app_environment.dart';
import 'core/di/service_locator.dart';
import 'core/observability/sentry_bloc_observer.dart';

Future<void> main() async {
  // Sentry's appRunner wraps everything in a guarded Zone so async errors
  // outside the widget tree are still captured. When no DSN is configured
  // (local debug builds) we skip Sentry but still install a Flutter error
  // handler so issues surface in the console.
  if (AppEnvironment.sentryEnabled) {
    await SentryFlutter.init(
      (options) {
        options.dsn = AppEnvironment.sentryDsn;
        options.environment = AppEnvironment.flavor;
        options.tracesSampleRate = AppEnvironment.sentryTracesSampleRate;
        // Drop PII the SDK would otherwise auto-attach (device IP, IMEI).
        // We don't need it and most data-protection regimes prefer it off.
        options.sendDefaultPii = false;
        // Don't ship Sentry events from local debug builds even if a DSN
        // somehow leaks into one.
        options.debug = false;
      },
      appRunner: _bootstrap,
    );
  } else {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (kDebugMode) debugPrint('[FlutterError] ${details.exception}');
    };
    await _bootstrap();
  }
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Route every unhandled BLoC error through Sentry (expected ApiExceptions
  // like network/timeout/permission are filtered out inside the observer).
  if (AppEnvironment.sentryEnabled) {
    Bloc.observer = SentryBlocObserver();
  }
  // Load the full IANA timezone database so we can render Odoo datetimes
  // in the user's `res.users.tz` regardless of the device's clock.
  tz_data.initializeTimeZones();
  await setupServiceLocator();
  runApp(const CustomerVisitsApp());
}
