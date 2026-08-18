import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;

import 'app/app.dart';
import 'core/config/app_environment.dart';
import 'core/di/service_locator.dart';
import 'core/observability/sentry_bloc_observer.dart';
import 'core/observability/sentry_noise_filter.dart';
import 'core/push/push_notification_service.dart';
import 'firebase_options.dart';
import 'core/utils/app_log.dart';

Future<void> main() async {
  // Sentry's appRunner wraps everything in a guarded Zone so async errors
  // outside the widget tree are still captured. When no DSN is configured
  // (local debug builds) we skip Sentry but still install a Flutter error
  // handler so issues surface in the console.
  if (AppEnvironment.sentryEnabled) {
    // Reading the version from the bundle rather than hardcoding it means a
    // release tag becomes the Sentry release automatically -- pubspec.yaml
    // stays the single source of truth and there is no second number to bump.
    // PackageInfo needs the platform channels, so bind first; `_bootstrap`
    // calls this again, which is a no-op.
    WidgetsFlutterBinding.ensureInitialized();
    final packageInfo = await PackageInfo.fromPlatform();

    await SentryFlutter.init(
      (options) {
        options.dsn = AppEnvironment.sentryDsn;
        options.environment = AppEnvironment.sentryEnvironment;
        options.release = '${packageInfo.packageName}@${packageInfo.version}'
            '+${packageInfo.buildNumber}';
        options.dist = packageInfo.buildNumber;
        options.tracesSampleRate = AppEnvironment.sentryTracesSampleRate;
        // Drop PII the SDK would otherwise auto-attach (device IP, IMEI).
        // We don't need it and most data-protection regimes prefer it off.
        options.sendDefaultPii = false;
        // A screenshot of this app is a customer's name, address and the rep's
        // live position -- never worth uploading to a third party for a stack
        // trace we can already read. Same for the widget tree.
        options.attachScreenshot = false;
        options.attachViewHierarchy = false;
        // Environmental failures (offline, 4xx, expired session) are already
        // shown to the user as normal messages. Reporting them buries the real
        // crashes and burns the quota. See [isSentryNoise].
        options.beforeSend =
            (event, hint) => isSentryNoise(event.throwable) ? null : event;
        // Don't ship Sentry events from local debug builds even if a DSN
        // somehow leaks into one.
        options.debug = false;
      },
      appRunner: _bootstrap,
    );
  } else {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      appLog('[FlutterError] ${details.exception}');
    };
    await _bootstrap();
  }
}

/// Ceiling on Flutter's decoded-image cache.
///
/// The default is 100 MiB / 1000 entries, which is sized for a device with
/// memory to spare. This app's only images are OSM map tiles — 256×256 PNGs
/// that decode to ~256 KB each in RGBA — plus one logo, and four screens show a
/// map (dashboard, route, visit detail, nearby radar). The nearby map alone
/// keeps a 5-tile buffer around the viewport, so a rep who pans around a city
/// can fill the default cache with tiles they will never look at again and hold
/// ~100 MB resident. On the 1–2 GB phones this app is deployed to, that is the
/// difference between staying alive in the background and being killed — which
/// for a GPS check-in app means losing the visit in progress.
///
/// 32 MiB still holds roughly two full screens of tiles, so panning back a
/// little is instant, while leaving the process footprint somewhere Android's
/// low-memory killer will tolerate.
const int _imageCacheBytes = 32 * 1024 * 1024;
const int _imageCacheEntries = 160;

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  PaintingBinding.instance.imageCache
    ..maximumSizeBytes = _imageCacheBytes
    ..maximumSize = _imageCacheEntries;
  // Route every unhandled BLoC error through Sentry (expected ApiExceptions
  // like network/timeout/permission are filtered out inside the observer).
  if (AppEnvironment.sentryEnabled) {
    Bloc.observer = SentryBlocObserver();
  }
  // Load the full IANA timezone database so we can render Odoo datetimes
  // in the user's `res.users.tz` regardless of the device's clock.
  tz_data.initializeTimeZones();

  // Load intl's date symbols for the locales we ship. Without this,
  // `DateFormat(..., 'ar')` throws on first use; see [AppDate].
  //
  // Named explicitly rather than calling the no-arg form: that one deserialises
  // the symbol *and* pattern data for every locale intl knows about (~180) on
  // the startup path, to serve an app whose `supportedLocales` is two entries
  // long. This is measured before the first frame, so it is pure launch cost.
  await Future.wait([
    initializeDateFormatting('en'),
    initializeDateFormatting('ar'),
  ]);

  // Firebase + push. initializeApp must run before any FCM use (including the
  // background isolate handler, which we register here at startup). A failure
  // here (e.g. missing google-services.json in a local build) must not take the
  // whole app down — notifications just stay off.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    appLog('[push] Firebase init failed: $e');
  }

  await setupServiceLocator();

  runApp(const CustomerVisitsApp());

  // Deliberately after `runApp` and deliberately not awaited: this asks the OS
  // for notification permission and registers platform handlers, none of which
  // the first frame depends on. Awaiting it kept the native splash up for the
  // whole round trip — on a cold start on a slow device that is the difference
  // between the app appearing to launch and appearing to hang.
  unawaited(_initPush());
}

Future<void> _initPush() async {
  try {
    // Wire up FCM handlers (permission, foreground banner, tap → deep link).
    // Token registration itself happens after login (see app.dart).
    await sl<PushNotificationService>().initialize();
  } catch (e) {
    appLog('[push] handler setup failed: $e');
  }
}
