import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'routes.dart';

import '../core/api/api_client.dart';
import '../core/api/api_exceptions.dart';
import '../core/config/server_config_cubit.dart';
import '../core/config/server_config_repository.dart';
import '../core/di/service_locator.dart';
import '../core/map_matching/route_matcher.dart';
import '../core/network/connectivity_status.dart';
import '../core/network/pending_actions_queue.dart';
import '../core/push/push_notification_service.dart';
import '../core/settings/settings_cubit.dart';
import '../core/settings/settings_repository.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/customers/bloc/customers_bloc.dart';
import '../features/customers/data/customers_repository.dart';
import '../features/visits/bloc/visit_bloc.dart';
import '../features/visits/bloc/visits_list_bloc.dart';
import '../features/visits/data/visits_repository.dart';
import '../features/visits/data/visit_trail_tracker.dart';
import '../features/workday/data/workday_tracker.dart';
import '../l10n/generated/app_localizations.dart';
import 'router.dart';
import 'theme.dart';
import '../shared/bloc/searchable_list_bloc.dart';

class CustomerVisitsApp extends StatefulWidget {
  const CustomerVisitsApp({super.key});

  @override
  State<CustomerVisitsApp> createState() => _CustomerVisitsAppState();
}

class _CustomerVisitsAppState extends State<CustomerVisitsApp>
    with WidgetsBindingObserver {
  late final AuthBloc _authBloc;
  late final SettingsCubit _settingsCubit;
  late final ServerConfigCubit _serverConfigCubit;
  late final GoRouter _router;
  final PushNotificationService _push = sl<PushNotificationService>();
  StreamSubscription<void>? _unauthorizedSub;
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<int>? _visitTapSub;

  /// A visit id from a notification tapped before we were authenticated
  /// (e.g. cold launch straight from a push). Navigated once logged in.
  int? _pendingVisitId;

  /// The sign-out clean-up in progress, shared by every logout request that
  /// arrives meanwhile. Unregistering the push token can itself be refused
  /// with a 401, which used to queue a second logout that ran the whole
  /// clean-up again in parallel.
  Future<void>? _logoutCleanup;

  AuthStatus? _lastStatus;

  @override
  void initState() {
    super.initState();
    _authBloc = AuthBloc(
      repository: sl<AuthRepository>(),
      // Stop recording the visit trail (nobody is tracked while signed out)
      // after pushing what it recorded, and unregister the FCM token — both
      // while the session is still valid.
      onBeforeLogout: () => _logoutCleanup ??= _cleanUpBeforeLogout(),
    )..add(const AuthStarted());
    _settingsCubit = SettingsCubit(
      repository: sl<SettingsRepository>(),
      // The Android channel name is shown in system settings, in the app's
      // language.
      onLocaleChanged: (_) => _push.refreshChannel(),
      // Only a signed-in device has a token the server knows about.
      onNotificationsChanged: (enabled) async {
        if (_authBloc.state.status == AuthStatus.authenticated) {
          await _push.setEnabled(enabled);
        }
      },
    );
    _serverConfigCubit = ServerConfigCubit(
      repository: sl<ServerConfigRepository>(),
      apiClient: sl<ApiClient>(),
    );
    // Build the router once so its lifetime (and our nav calls into it) is
    // stable across rebuilds.
    _router = buildRouter(_authBloc, _serverConfigCubit);

    // Any API call returning 401/AUTH_REQUIRED forces a logout, which the
    // router will pick up and redirect to /login.
    _unauthorizedSub = sl<ApiClient>().onUnauthorized.listen((_) {
      if (_authBloc.state.status == AuthStatus.authenticated &&
          _logoutCleanup == null) {
        // Pass the cause along: without it the user is thrown back to the
        // login screen mid-task with no idea whether they were signed out,
        // mis-tapped, or hit a crash.
        _authBloc.add(AuthLogoutRequested(reason: ApiException.unauthorized()));
      }
    });

    // Register the device token whenever the user becomes authenticated (covers
    // both a fresh login and a cold start with an existing session), and flush
    // any visit deep-link that arrived before login.
    _authSub = _authBloc.stream.listen((state) {
      final changed = state.status != _lastStatus;
      _lastStatus = state.status;
      if (!changed) return;
      // Offline work is scoped to the signed-in user: re-scope on every
      // change, and send what this user has waiting once they're in.
      final queue = slMaybe<PendingActionsQueue>();
      if (state.status == AuthStatus.authenticated) {
        _logoutCleanup = null;
        unawaited(_push.registerToken());
        unawaited(queue?.refreshOwner().then((_) => queue.flush()));
        _flushPendingVisit();
      } else {
        unawaited(queue?.refreshOwner());
      }
    });

    // A tapped visit notification → open the visit (or defer until logged in).
    _visitTapSub = _push.onVisitTap.listen(_handleVisitTap);

    // A token registration that failed (offline at sign-in, APNs not ready)
    // is retried once the network is back and whenever the app is reopened.
    _connectivity = slMaybe<ConnectivityStatus>();
    _connectivity?.addListener(_onConnectivity);
    WidgetsBinding.instance.addObserver(this);
  }

  ConnectivityStatus? _connectivity;

  void _onConnectivity() {
    if (_connectivity?.isOnline ?? false) _retryPushRegistration();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _retryPushRegistration();
  }

  void _retryPushRegistration() {
    if (_authBloc.state.status == AuthStatus.authenticated) {
      unawaited(_push.retryRegistration());
    }
  }

  /// Stops recording the visit trail (nobody is tracked while signed out)
  /// after pushing what it recorded, then unregisters the FCM token — all
  /// while the session is still valid.
  Future<void> _cleanUpBeforeLogout() async {
    await slMaybe<VisitTrailTracker>()?.suspend();
    await slMaybe<WorkdayTracker>()?.suspend();
    await _push.unregister();
    // Matched road geometry describes where this employee went.
    await slMaybe<RouteMatcher>()?.clear();
  }

  void _handleVisitTap(int visitId) {
    if (_authBloc.state.status == AuthStatus.authenticated) {
      _openVisit(visitId);
    } else {
      _pendingVisitId = visitId;
    }
  }

  void _flushPendingVisit() {
    final id = _pendingVisitId;
    if (id == null) return;
    _pendingVisitId = null;
    _openVisit(id);
  }

  void _openVisit(int visitId) {
    // Defer to after the current frame so any auth-driven redirect (→ /home)
    // settles first and the visit page pushes cleanly on top.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _router.push(AppRoutes.visitDetail(visitId));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivity?.removeListener(_onConnectivity);
    _unauthorizedSub?.cancel();
    _authSub?.cancel();
    _visitTapSub?.cancel();
    _router.dispose();
    _authBloc.close();
    _settingsCubit.close();
    _serverConfigCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _authBloc),
        BlocProvider.value(value: _settingsCubit),
        BlocProvider.value(value: _serverConfigCubit),
        BlocProvider(
          create: (_) =>
              CustomersBloc(repository: sl<CustomersRepository>()),
        ),
        BlocProvider(
          create: (_) => VisitBloc(repository: sl<VisitsRepository>()),
        ),
        BlocProvider(
          create: (_) =>
              VisitsListBloc(repository: sl<VisitsRepository>()),
        ),
      ],
      child: BlocListener<AuthBloc, AuthState>(
        // Every bloc below lives as long as the app, so a sign-out must wipe
        // them by hand: otherwise the next account inherits the previous one's
        // cached lists *and* filters. (A stale `searchQuery` left over from the
        // signed-out user silently filtered the incoming user's visits down to
        // an empty list, while the recreated search field looked empty.)
        listenWhen: (prev, curr) =>
            prev.status == AuthStatus.authenticated &&
            curr.status != AuthStatus.authenticated,
        listener: (context, _) => _resetUserScopedBlocs(context),
        child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, settings) {
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: settings.themeMode,
            routerConfig: _router,
            // App-wide responsiveness guard: bound the OS text-scale so the
            // design's fixed-height components (app bar, cards, chips, nav)
            // stay legible without overflowing on very large / small font
            // accessibility settings.
            builder: (context, child) => MediaQuery.withClampedTextScaling(
              minScaleFactor: Responsive.minTextScale,
              maxScaleFactor: Responsive.maxTextScale,
              child: child!,
            ),
            locale: settings.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
          );
        },
        ),
      ),
    );
  }

  /// Drops every app-scoped bloc that holds user data back to its initial
  /// state. Called the moment authentication is lost (manual sign-out or a
  /// 401 from the API) so nothing survives into the next session.
  void _resetUserScopedBlocs(BuildContext context) {
    context.read<VisitsListBloc>().add(const VisitsListReset());
    context.read<VisitBloc>().add(const VisitCleared());
    context.read<CustomersBloc>().add(const ListReset());
  }
}
