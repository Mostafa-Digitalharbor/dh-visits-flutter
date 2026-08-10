import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/design/app_assets.dart';
import '../../app/design/app_colors.dart';
import '../../firebase_options.dart';
import '../../l10n/generated/app_localizations.dart';
import 'push_repository.dart';
import '../utils/app_log.dart';

/// Handles a push received while the app is in the background or terminated.
///
/// Must be a top-level (or static) function annotated with `vm:entry-point`
/// because Flutter runs it in a **separate isolate** with no access to app
/// state — so we can't touch the [PushNotificationService] instance here.
/// The OS already renders the `notification` payload; the actual tap is picked
/// up by [FirebaseMessaging.getInitialMessage] / `onMessageOpenedApp` once the
/// app resumes. We only need to make sure Firebase is initialised in this
/// isolate.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// Owns the whole FCM lifecycle for the app:
///
/// * asks for notification permission and configures the foreground banner,
/// * registers / unregisters the device's FCM token with the backend
///   ([PushRepository]) around login / logout,
/// * turns a notification tap into a visit id on [onVisitTap] so the app can
///   deep-link to `/visits/<id>`.
///
/// The backend contract (payload shape, `data.visit_id`) lives in
/// docs/BACKEND_PUSH_NOTIFICATIONS.md.
class PushNotificationService {
  PushNotificationService({required this.repository, required this.prefs});

  final PushRepository repository;
  final SharedPreferences prefs;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const _deviceIdKey = 'push_device_id';
  static const _lastTokenKey = 'push_last_token';

  /// Android channel id for visit events. Must match the id we pass to
  /// [_local.show] and the `default_notification_channel_id` in the manifest.
  static const String _channelId = 'visit_events';

  /// Accent Android tints the status-bar silhouette and header with.
  ///
  /// Must stay in sync with `@color/notification_accent`
  /// (`android/app/src/main/res/values/colors.xml`), which the manifest points
  /// `default_notification_color` at for the pushes the OS renders itself.
  /// Both paths have to agree or a foreground notification looks like a
  /// different app's than the same message received in the background.
  static const Color _accent = AppColors.notificationAccent;

  /// The channel's name and description are user-visible — Android lists them
  /// under Settings → Notifications — so they are localized like any other
  /// string. There's no BuildContext here, so the locale comes from the same
  /// preference the app itself reads, via [lookupAppLocalizations].
  ///
  /// Re-created (same id) on locale change so the OS picks up the new labels;
  /// Android updates an existing channel's name/description in place.
  AndroidNotificationChannel _buildChannel() {
    final s = lookupAppLocalizations(_currentLocale());
    return AndroidNotificationChannel(
      _channelId,
      s.pushChannelName,
      description: s.pushChannelDescription,
      importance: Importance.high,
    );
  }

  Locale _currentLocale() {
    final code = prefs.getString('pref_locale');
    return Locale(code == null || code.isEmpty ? 'en' : code);
  }

  /// (Re)registers the Android channel with labels in the current language.
  /// Call after the user switches languages so Settings → Notifications stops
  /// showing the previous one.
  Future<void> refreshChannel() async {
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_buildChannel());
  }

  // Single-subscription (not broadcast) on purpose: it buffers events emitted
  // before the app attaches its listener, so a tap that launched the app from a
  // terminated state (delivered via getInitialMessage during [initialize]) is
  // not lost. Only the app shell listens.
  final StreamController<int> _visitTaps = StreamController<int>();

  /// Emits a visit id whenever the user taps a visit notification (foreground,
  /// background-resume, or cold launch).
  Stream<int> get onVisitTap => _visitTaps.stream;

  StreamSubscription<String>? _tokenRefreshSub;
  bool _initialized = false;

  /// One-time setup: local-notification plugin, Android channel, permission,
  /// and the three FCM tap entry points. Safe to call once at startup.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Local notifications — used to show a heads-up while the app is in the
    //    foreground (FCM does not auto-display in that case).
    const androidInit =
        AndroidInitializationSettings(AppAssets.androidNotificationIcon);
    const iosInit = DarwinInitializationSettings(
      // firebase_messaging.requestPermission() handles the iOS prompt below,
      // so the local plugin must not ask again.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final id = _visitIdFromPayload(response.payload);
        if (id != null) _visitTaps.add(id);
      },
    );
    await refreshChannel();

    // 2. Permission (iOS always; Android 13+ POST_NOTIFICATIONS runtime prompt).
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // 3. iOS: allow the banner to show while the app is foregrounded.
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 4. Foreground message → render it ourselves via the local plugin.
    FirebaseMessaging.onMessage.listen(_showForeground);

    // 5. Tap that brought the app from background to foreground.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final id = _visitIdFromData(message.data);
      if (id != null) _visitTaps.add(id);
    });

    // 6. Tap that cold-launched the app from a terminated state.
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      final id = _visitIdFromData(initial.data);
      if (id != null) _visitTaps.add(id);
    }
  }

  /// Sends the current FCM token to the backend. Call after each successful
  /// login (and on app resume with an existing session) — the token can change,
  /// and registration must happen while the session cookie is valid.
  Future<void> registerToken() async {
    try {
      final token = await _fcm.getToken();
      if (token == null) return;
      await repository.registerDevice(
        token: token,
        platform: _platform(),
        deviceId: await _deviceId(),
      );
      await prefs.setString(_lastTokenKey, token);
      appLog('[push] token registered');

      // Keep the server in sync if the token rotates while signed in.
      _tokenRefreshSub ??= _fcm.onTokenRefresh.listen((newToken) async {
        try {
          await repository.registerDevice(
            token: newToken,
            platform: _platform(),
            deviceId: await _deviceId(),
          );
          await prefs.setString(_lastTokenKey, newToken);
          appLog('[push] token refreshed & re-registered');
        } catch (e) {
          appLog('[push] token refresh registration failed: $e');
        }
      });
    } catch (e) {
      // Best-effort: a failed registration must never block login.
      appLog('[push] registerToken failed: $e');
    }
  }

  /// Removes the token from the backend and this device. Call *before* the
  /// session is destroyed on logout so the server request is still authorised.
  Future<void> unregister() async {
    try {
      final token = prefs.getString(_lastTokenKey) ?? await _fcm.getToken();
      if (token != null) {
        await repository.unregisterDevice(token: token);
      }
      // Invalidate the token locally so a signed-out device stops receiving
      // pushes even if the server call above failed.
      await _fcm.deleteToken();
      await prefs.remove(_lastTokenKey);
      appLog('[push] token unregistered');
    } catch (e) {
      appLog('[push] unregister failed: $e');
    }
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    // Prefer the `notification` block (the documented contract), but fall back
    // to `data.title` / `data.body` so a mistakenly data-only message still
    // shows *something* in the foreground instead of vanishing. (Note: a
    // data-only message can never be shown by the OS in the background — the
    // backend MUST include a `notification` block; see
    // docs/BACKEND_PUSH_NOTIFICATIONS.md.)
    final title = notification?.title ?? message.data['title'] as String?;
    final body = notification?.body ?? message.data['body'] as String?;
    // Genuinely nothing to display (a pure silent data sync) → skip.
    if (title == null && body == null) return;
    final channel = _buildChannel();
    await _local.show(
      notification?.hashCode ?? message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.high,
          priority: Priority.high,
          // Status-bar silhouette (alpha-only — see [AppAssets]) …
          icon: AppAssets.androidNotificationIcon,
          // … plus the full-colour launcher icon in the notification body, so
          // the brand mark is actually recognisable and not just a monochrome
          // stamp. Only reachable on this foreground path; the OS renders
          // background/terminated pushes itself and will only show a large icon
          // if the backend sends one. See docs/BACKEND_PUSH_NOTIFICATIONS.md.
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          color: _accent,
          colorized: false,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      // Carried back to onDidReceiveNotificationResponse on tap.
      payload: message.data['visit_id']?.toString(),
    );
  }

  String _platform() => Platform.isIOS ? 'ios' : 'android';

  /// A stable per-install id so the backend can de-duplicate tokens for the
  /// same device. Generated once and persisted (no external uuid dependency).
  Future<String> _deviceId() async {
    var id = prefs.getString(_deviceIdKey);
    if (id == null || id.isEmpty) {
      final rand = Random.secure();
      id = List.generate(32, (_) => rand.nextInt(16).toRadixString(16)).join();
      await prefs.setString(_deviceIdKey, id);
    }
    return id;
  }

  int? _visitIdFromData(Map<String, dynamic> data) {
    final raw = data['visit_id'];
    if (raw == null) return null;
    return int.tryParse(raw.toString());
  }

  int? _visitIdFromPayload(String? payload) =>
      (payload == null || payload.isEmpty) ? null : int.tryParse(payload);

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _visitTaps.close();
  }
}
