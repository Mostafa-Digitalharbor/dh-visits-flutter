import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../firebase_options.dart';
import 'push_repository.dart';

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

  /// Android channel for visit events. Must be created up front (Android 8+)
  /// and its id must match the one we pass to [_local.show].
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'visit_events',
    'Visit updates',
    description: 'Approvals, reschedules and status changes for your visits.',
    importance: Importance.high,
  );

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
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
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
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

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
      debugPrint('[push] token registered');

      // Keep the server in sync if the token rotates while signed in.
      _tokenRefreshSub ??= _fcm.onTokenRefresh.listen((newToken) async {
        try {
          await repository.registerDevice(
            token: newToken,
            platform: _platform(),
            deviceId: await _deviceId(),
          );
          await prefs.setString(_lastTokenKey, newToken);
          debugPrint('[push] token refreshed & re-registered');
        } catch (e) {
          debugPrint('[push] token refresh registration failed: $e');
        }
      });
    } catch (e) {
      // Best-effort: a failed registration must never block login.
      debugPrint('[push] registerToken failed: $e');
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
      debugPrint('[push] token unregistered');
    } catch (e) {
      debugPrint('[push] unregister failed: $e');
    }
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    // The documented payload always carries a `notification` block. If a
    // data-only message arrives with nothing to show, skip silently.
    if (notification == null) return;
    await _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
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
