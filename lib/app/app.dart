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
import '../core/location/location_service.dart';
import '../core/map_matching/route_matcher.dart';
import '../core/push/push_notification_service.dart';
import '../core/settings/settings_cubit.dart';
import '../core/settings/settings_repository.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/customers/bloc/customers_bloc.dart';
import '../features/customers/data/customers_repository.dart';
import '../features/live_location/bloc/live_location_bloc.dart';
import '../features/live_location/data/live_location_repository.dart';
import '../features/nearby/bloc/nearby_bloc.dart';
import '../features/nearby/data/nearby_repository.dart';
import '../features/visits/bloc/visit_bloc.dart';
import '../features/visits/bloc/visits_list_bloc.dart';
import '../features/visits/data/visits_repository.dart';
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

class _CustomerVisitsAppState extends State<CustomerVisitsApp> {
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

  @override
  void initState() {
    super.initState();
    _authBloc = AuthBloc(
      repository: sl<AuthRepository>(),
      // Unregister the FCM token while the session is still valid, and stop
      // work-day capture (nobody is tracked while signed out) after pushing
      // what it recorded.
      onBeforeLogout: () async {
        await _push.unregister();
        await slMaybe<WorkdayTracker>()?.suspend();
        // Matched road geometry describes where this employee went.
        await slMaybe<RouteMatcher>()?.clear();
      },
    )..add(const AuthStarted());
    _settingsCubit =
        SettingsCubit(repository: sl<SettingsRepository>());
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
      if (_authBloc.state.status == AuthStatus.authenticated) {
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
      if (state.status == AuthStatus.authenticated) {
        _push.registerToken();
        _flushPendingVisit();
      }
    });

    // A tapped visit notification → open the visit (or defer until logged in).
    _visitTapSub = _push.onVisitTap.listen(_handleVisitTap);
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
    _unauthorizedSub?.cancel();
    _authSub?.cancel();
    _visitTapSub?.cancel();
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
        BlocProvider(
          create: (_) => LiveLocationBloc(
            repository: sl<LiveLocationRepository>(),
            locationService: sl<LocationService>(),
          ),
        ),
        BlocProvider(
          create: (_) => NearbyBloc(
            nearbyRepository: sl<NearbyRepository>(),
            customersRepository: sl<CustomersRepository>(),
          ),
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
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(
                  textScaler: mq.textScaler.clamp(
                    minScaleFactor: 0.9,
                    maxScaleFactor: 1.25,
                  ),
                ),
                child: child!,
              );
            },
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
    context.read<NearbyBloc>().add(const NearbyReset());
    // Stop pinging the employee's GPS once they're signed out.
    context.read<LiveLocationBloc>().add(const LiveLocationStopRequested());
  }
}
