import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/design/app_assets.dart';
import '../../app/design/app_colors.dart';
import '../../firebase_options.dart';
import '../../l10n/generated/app_localizations.dart';
import '../constants.dart';
import '../utils/app_log.dart';
import 'device_identity.dart';
import 'push_repository.dart';

/// One visit-workflow push, as the backend sends it (API.md §4.9). Every
/// value of the `data` block is a string; [visitId] is parsed from it.
class VisitPushEvent {
  final int visitId;

  /// `submitted`, `approved`, `completed`, … — null when absent.
  final String? event;

  /// The visit reference, e.g. `VIS/2026/00052`.
  final String? reference;

  /// The visit's state after the event, as the server reported it.
  final String? state;

  const VisitPushEvent({
    required this.visitId,
    this.event,
    this.reference,
    this.state,
  });

  /// Null unless [data] carries a numeric `visit_id`.
  static VisitPushEvent? fromData(Map<String, dynamic> data) {
    final visitId = int.tryParse(data[PushPayload.visitId]?.toString() ?? '');
    if (visitId == null) return null;
    String? text(String key) {
      final value = data[key]?.toString();
      return value == null || value.isEmpty ? null : value;
    }

    return VisitPushEvent(
      visitId: visitId,
      event: text(PushPayload.event),
      reference: text(PushPayload.reference),
      state: text(PushPayload.state),
    );
  }
}

/// Keys of the push `data` block (the backend contract).
abstract final class PushPayload {
  static const visitId = 'visit_id';
  static const event = 'event';
  static const reference = 'visit_ref';
  static const state = 'state';
  static const title = 'title';
  static const body = 'body';
}

/// The localized title of a visit event, for a push the backend sent without
/// a `notification` block. Unknown events get a generic title.
String visitEventTitle(AppLocalizations s, String? event) => switch (event) {
      'submitted' => s.pushEventSubmitted,
      'participation_approval' => s.pushEventParticipationApproval,
      'ready_for_approval' => s.pushEventReadyForApproval,
      'approved' => s.pushEventApproved,
      'rejected' => s.pushEventRejected,
      'participant_rejected' => s.pushEventParticipantRejected,
      'reschedule_requested' => s.pushEventRescheduleRequested,
      'reschedule_approved' => s.pushEventRescheduleApproved,
      'escalated' => s.pushEventEscalated,
      'started' => s.pushEventStarted,
      'completed' => s.pushEventCompleted,
      'cancelled' => s.pushEventCancelled,
      _ => s.pushEventUpdated,
    };

/// Handles a push received while the app is in the background or terminated.
///
/// Must be a top-level (or static) function annotated with `vm:entry-point`
/// because Flutter runs it in a **separate isolate** with no access to app
/// state. A push with a `notification` block is rendered by the OS itself; a
/// data-only one would vanish, so it is rendered here from its `event`. The
/// tap is picked up by [FirebaseMessaging.getInitialMessage] /
/// `onMessageOpenedApp` (or the local plugin's launch details) once the app
/// opens. Nothing here touches location tracking.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (message.notification != null) return;
  try {
    WidgetsFlutterBinding.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    await PushNotificationService.showDataOnly(
      FlutterLocalNotificationsPlugin(),
      prefs,
      message,
      initialize: true,
    );
  } catch (e) {
    appLog('[push] background notification failed: $e');
  }
}

/// Owns the whole FCM lifecycle for the app:
///
/// * asks for notification permission and configures the foreground banner,
/// * registers / unregisters the device's FCM token with the backend
///   ([PushRepository]) around login / logout, token rotation and the
///   Notifications setting,
/// * turns a notification tap into a visit id on [onVisitTap] so the app can
///   deep-link to `/visits/<id>`, and reports every visit push on
///   [onVisitEvent] so screens and the trail tracker can re-read the visit.
///
/// Firebase may be missing (a local build without `google-services.json`):
/// `main` tolerates that, so every entry point here checks [_firebaseReady]
/// instead of assuming it. Push then simply stays off.
///
/// The backend contract (payload shape, `data.visit_id`) is docs/API.md §4.9.
class PushNotificationService {
  PushNotificationService({
    required this.repository,
    required this.prefs,
    DeviceIdentity? identity,
  }) : _identity = identity ?? DeviceIdentity(prefs: prefs);

  final PushRepository repository;
  final SharedPreferences prefs;
  final DeviceIdentity _identity;

  // Late, not eager: `FirebaseMessaging.instance` throws when Firebase failed
  // to initialise, and this service is built during app start-up — an eager
  // field turned "notifications stay off" into "the app never starts".
  late final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const _lastTokenKey = StorageKeys.pushLastToken;

  /// Android channel id for visit events. Must match the id we pass to
  /// `show` and the `default_notification_channel_id` in the manifest.
  static const String _channelId = 'visit_events';

  /// `platform` values `register_device` accepts.
  static const String _platformIos = 'ios';
  static const String _platformAndroid = 'android';

  /// Longest logout waits for the server to forget the token. Offline, the
  /// call would otherwise hold sign-out for the whole connect timeout.
  static const Duration _unregisterTimeout = Duration(seconds: 5);

  /// iOS hands out an FCM token only once APNs has issued its own; right after
  /// launch that can take a moment.
  static const int _apnsAttempts = 5;
  static const Duration _apnsDelay = Duration(seconds: 1);

  /// Android notification ids are signed 32-bit integers.
  static const int _maxNotificationId = 0x7fffffff;

  /// Accent Android tints the status-bar silhouette and header with.
  ///
  /// Must stay in sync with `@color/notification_accent`
  /// (`android/app/src/main/res/values/colors.xml`), which the manifest points
  /// `default_notification_color` at for the pushes the OS renders itself.
  static const Color _accent = AppColors.notificationAccent;

  bool get _firebaseReady => Firebase.apps.isNotEmpty;

  /// The user's Notifications setting. On by default.
  bool get _enabled => _enabledIn(prefs);

  static bool _enabledIn(SharedPreferences prefs) {
    try {
      return prefs.getBool(StorageKeys.notifications) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// A signed-in user wants this device registered. Set by [registerToken],
  /// cleared by [unregister]; a token rotation is only sent while it is set.
  bool _wanted = false;

  /// Whether the last registration attempt reached the server.
  bool _registered = false;

  /// The channel's name and description are user-visible — Android lists them
  /// under Settings → Notifications — so they are localized like any other
  /// string. There's no BuildContext here, so the locale comes from the same
  /// preference the app itself reads, with the same default.
  ///
  /// Re-created (same id) on locale change so the OS picks up the new labels;
  /// Android updates an existing channel's name/description in place.
  static AndroidNotificationChannel _buildChannel(SharedPreferences prefs) {
    final s = lookupAppLocalizations(_localeOf(prefs));
    return AndroidNotificationChannel(
      _channelId,
      s.pushChannelName,
      description: s.pushChannelDescription,
      importance: Importance.high,
    );
  }

  static Locale _localeOf(SharedPreferences prefs) {
    try {
      return AppLocales.fromCode(prefs.getString(StorageKeys.locale));
    } catch (_) {
      return AppLocales.fallback;
    }
  }

  /// (Re)registers the Android channel with labels in the current language.
  /// Called at start-up and whenever the user switches languages, so
  /// Settings → Notifications never shows the previous one.
  Future<void> refreshChannel() async {
    try {
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_buildChannel(prefs));
    } catch (e) {
      appLog('[push] channel refresh failed: $e');
    }
  }

  // Single-subscription (not broadcast) on purpose: it buffers events emitted
  // before the app attaches its listener, so a tap that launched the app from a
  // terminated state (delivered via getInitialMessage during [initialize]) is
  // not lost. Only the app shell listens.
  final StreamController<int> _visitTaps = StreamController<int>();

  /// Emits a visit id whenever the user taps a visit notification (foreground,
  /// background-resume, or cold launch).
  Stream<int> get onVisitTap => _visitTaps.stream;

  final StreamController<VisitPushEvent> _visitEvents =
      StreamController<VisitPushEvent>.broadcast();

  /// Every visit push this process sees: received in the foreground, or
  /// opened from the notification tray. A signal to re-read the visit from
  /// the server — never a reason to start anything.
  Stream<VisitPushEvent> get onVisitEvent => _visitEvents.stream;

  StreamSubscription<String>? _tokenRefreshSub;
  final List<StreamSubscription<RemoteMessage>> _messageSubs = [];
  bool _initialized = false;

  /// One-time setup: local-notification plugin, Android channel, permission,
  /// the FCM tap entry points and the token-rotation listener.
  ///
  /// Each step is tried on its own: a refused permission prompt must not
  /// leave taps unhandled for the rest of the session. The service counts as
  /// initialized only once the handlers are attached.
  Future<void> initialize() async {
    if (_initialized) return;

    // 1. Local notifications — used to show a heads-up while the app is in the
    //    foreground (FCM does not auto-display in that case), and for
    //    data-only pushes.
    await _step('local notifications', () async {
      await _initLocal(
        _local,
        onTap: (response) => _emitTap(_visitIdFromPayload(response.payload)),
      );
      await refreshChannel();
      // A data-only push rendered by the background handler, tapped while the
      // app was not running.
      final launch = await _local.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _emitTap(_visitIdFromPayload(launch?.notificationResponse?.payload));
      }
    });

    if (!_firebaseReady) {
      appLog('[push] Firebase unavailable; push notifications stay off');
      return;
    }

    // 2. Permission (iOS always; Android 13+ POST_NOTIFICATIONS runtime prompt).
    await _step('permission', () async {
      await _fcm.requestPermission(alert: true, badge: true, sound: true);
      // iOS: allow the banner to show while the app is foregrounded.
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    });

    await _step('message handlers', () async {
      // 3. Foreground message → render it ourselves via the local plugin.
      _messageSubs.add(FirebaseMessaging.onMessage.listen((message) {
        _emitEvent(message.data);
        unawaited(_showForeground(message));
      }));
      // 4. Tap that brought the app from background to foreground.
      _messageSubs.add(FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _emitEvent(message.data);
        _emitTap(VisitPushEvent.fromData(message.data)?.visitId);
      }));
      // 5. Token rotation, whenever it happens: sent while a user is signed in.
      _tokenRefreshSub ??= _fcm.onTokenRefresh.listen((token) async {
        if (!_wanted || !_enabled) return;
        await _registerOrMark(token, 'refreshed token');
      });
      _initialized = true;
      // 6. Tap that cold-launched the app from a terminated state.
      final initial = await _fcm.getInitialMessage();
      if (initial != null) {
        _emitEvent(initial.data);
        _emitTap(VisitPushEvent.fromData(initial.data)?.visitId);
      }
    });
  }

  static Future<void> _initLocal(
    FlutterLocalNotificationsPlugin plugin, {
    void Function(NotificationResponse)? onTap,
  }) {
    const androidInit =
        AndroidInitializationSettings(AppAssets.androidNotificationIcon);
    const iosInit = DarwinInitializationSettings(
      // firebase_messaging.requestPermission() handles the iOS prompt, so the
      // local plugin must not ask again.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    return plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: onTap,
    );
  }

  Future<void> _step(String name, Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      appLog('[push] $name setup failed: $e');
    }
  }

  void _emitTap(int? visitId) {
    if (visitId != null && !_visitTaps.isClosed) _visitTaps.add(visitId);
  }

  void _emitEvent(Map<String, dynamic> data) {
    final event = VisitPushEvent.fromData(data);
    if (event != null && !_visitEvents.isClosed) _visitEvents.add(event);
  }

  /// Sends the current FCM token to the backend. Call after each successful
  /// login (and on start-up with an existing session) — the token can change,
  /// and registration must happen while the session cookie is valid.
  ///
  /// Does nothing while the user has notifications switched off. A failure is
  /// remembered and retried by [retryRegistration].
  Future<void> registerToken() async {
    _wanted = true;
    if (!_firebaseReady || !_enabled) return;
    try {
      final token = await _currentToken();
      if (token == null) {
        _registered = false;
        return;
      }
      await _registerOrMark(token, 'token');
    } catch (e) {
      // Best-effort: a failed registration must never block login.
      _registered = false;
      appLog('[push] registerToken failed: $e');
    }
  }

  /// Registers again if the last attempt did not reach the server — call when
  /// the network comes back or the app returns to the foreground.
  Future<void> retryRegistration() async {
    if (!_wanted || _registered) return;
    await registerToken();
  }

  Future<void> _registerOrMark(String token, String what) async {
    try {
      await repository.registerDevice(
        token: token,
        platform: Platform.isIOS ? _platformIos : _platformAndroid,
        deviceId: await deviceId(),
      );
      await prefs.setString(_lastTokenKey, token);
      _registered = true;
      appLog('[push] $what registered');
    } catch (e) {
      _registered = false;
      appLog('[push] $what registration failed: $e');
    }
  }

  /// The FCM token. On iOS it waits briefly for the APNs token first:
  /// `getToken` throws while APNs has not issued one yet.
  Future<String?> _currentToken() async {
    if (Platform.isIOS) {
      String? apns;
      for (var i = 0; i < _apnsAttempts && apns == null; i++) {
        apns = await _fcm.getAPNSToken();
        if (apns == null) await Future<void>.delayed(_apnsDelay);
      }
      if (apns == null) {
        appLog('[push] APNs token not available yet');
        return null;
      }
    }
    return _fcm.getToken();
  }

  /// Applies the user's Notifications setting: registers the device again, or
  /// makes the server and this device forget it.
  Future<void> setEnabled(bool enabled) =>
      enabled ? registerToken() : _forget();

  /// Removes the token from the backend and this device. Call *before* the
  /// session is destroyed on logout so the server request is still authorised.
  ///
  /// The local deletion runs even when the server can't be reached: a
  /// signed-out device must stop receiving that user's pushes either way.
  Future<void> unregister() async {
    _wanted = false;
    await _forget();
  }

  Future<void> _forget() async {
    _registered = false;
    if (!_firebaseReady) return;

    String? token;
    try {
      token = prefs.getString(_lastTokenKey);
    } catch (_) {
      token = null;
    }
    try {
      token ??= await _fcm.getToken();
      if (token != null) {
        await repository
            .unregisterDevice(token: token)
            .timeout(_unregisterTimeout);
      }
    } catch (e) {
      appLog('[push] server unregister failed: $e');
    }

    try {
      await _fcm.deleteToken();
      await prefs.remove(_lastTokenKey);
      appLog('[push] token unregistered');
    } catch (e) {
      appLog('[push] local token deletion failed: $e');
    }
  }

  Future<void> _showForeground(RemoteMessage message) async {
    if (!_enabled) return;
    try {
      await _show(_local, prefs, message);
    } catch (e) {
      appLog('[push] foreground notification failed: $e');
    }
  }

  /// Renders a data-only push from its `event` (the background isolate).
  static Future<void> showDataOnly(
    FlutterLocalNotificationsPlugin plugin,
    SharedPreferences prefs,
    RemoteMessage message, {
    bool initialize = false,
  }) async {
    if (!_enabledIn(prefs) || message.notification != null) return;
    if (initialize) {
      await _initLocal(plugin);
      await plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_buildChannel(prefs));
    }
    await _show(plugin, prefs, message);
  }

  /// Shows [message]: the `notification` block when the backend sent one (the
  /// server's own, translated wording), else `data.title`/`data.body`, else a
  /// localized title from `data.event` with the visit reference.
  static Future<void> _show(
    FlutterLocalNotificationsPlugin plugin,
    SharedPreferences prefs,
    RemoteMessage message,
  ) async {
    final notification = message.notification;
    final data = message.data;
    final event = VisitPushEvent.fromData(data);
    final s = lookupAppLocalizations(_localeOf(prefs));
    var title = notification?.title ?? data[PushPayload.title]?.toString();
    var body = notification?.body ?? data[PushPayload.body]?.toString();
    if (title == null && body == null) {
      // Genuinely nothing to display (a pure silent data sync) → skip.
      if (event == null) return;
      title = visitEventTitle(s, event.event);
      body = event.reference ?? s.visitFallbackTitle(event.visitId);
    }
    final channel = _buildChannel(prefs);
    await plugin.show(
      // Keyed on the message id, so a redelivered push replaces its copy
      // instead of stacking a duplicate.
      (message.messageId ?? message.sentTime?.toIso8601String() ?? title)
              .hashCode &
          _maxNotificationId,
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
          // the brand mark is actually recognisable.
          largeIcon:
              const DrawableResourceAndroidBitmap(AppAssets.androidLauncherIcon),
          color: _accent,
          colorized: false,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      // Carried back to onDidReceiveNotificationResponse on tap.
      payload: event?.visitId.toString(),
    );
  }

  /// The stable per-device id — see [DeviceIdentity].
  Future<String> deviceId() => _identity.id();

  int? _visitIdFromPayload(String? payload) =>
      (payload == null || payload.isEmpty) ? null : int.tryParse(payload);

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    for (final sub in _messageSubs) {
      await sub.cancel();
    }
    await _visitTaps.close();
    await _visitEvents.close();
  }
}
