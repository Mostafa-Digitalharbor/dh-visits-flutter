import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/api/api_client.dart';
import '../core/di/service_locator.dart';
import '../core/location/location_service.dart';
import '../core/settings/settings_cubit.dart';
import '../core/settings/settings_repository.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/customers/bloc/customers_bloc.dart';
import '../features/customers/data/customers_repository.dart';
import '../features/employees/bloc/employees_bloc.dart';
import '../features/employees/data/employees_repository.dart';
import '../features/live_location/bloc/live_location_bloc.dart';
import '../features/live_location/data/live_location_repository.dart';
import '../features/nearby/bloc/nearby_bloc.dart';
import '../features/nearby/data/nearby_repository.dart';
import '../features/visits/bloc/visit_bloc.dart';
import '../features/visits/bloc/visits_list_bloc.dart';
import '../features/visits/data/visits_repository.dart';
import '../l10n/generated/app_localizations.dart';
import 'router.dart';
import 'theme.dart';

class CustomerVisitsApp extends StatefulWidget {
  const CustomerVisitsApp({super.key});

  @override
  State<CustomerVisitsApp> createState() => _CustomerVisitsAppState();
}

class _CustomerVisitsAppState extends State<CustomerVisitsApp> {
  late final AuthBloc _authBloc;
  late final SettingsCubit _settingsCubit;
  StreamSubscription<void>? _unauthorizedSub;

  @override
  void initState() {
    super.initState();
    _authBloc = AuthBloc(repository: sl<AuthRepository>())
      ..add(const AuthStarted());
    _settingsCubit =
        SettingsCubit(repository: sl<SettingsRepository>());
    // Any API call returning 401/AUTH_REQUIRED forces a logout, which the
    // router will pick up and redirect to /login.
    _unauthorizedSub = sl<ApiClient>().onUnauthorized.listen((_) {
      if (_authBloc.state.status == AuthStatus.authenticated) {
        _authBloc.add(const AuthLogoutRequested());
      }
    });
  }

  @override
  void dispose() {
    _unauthorizedSub?.cancel();
    _authBloc.close();
    _settingsCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = buildRouter(_authBloc);
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _authBloc),
        BlocProvider.value(value: _settingsCubit),
        BlocProvider(
          create: (_) =>
              CustomersBloc(repository: sl<CustomersRepository>()),
        ),
        BlocProvider(
          create: (_) =>
              EmployeesBloc(repository: sl<EmployeesRepository>()),
        ),
        BlocProvider(
          create: (_) => VisitBloc(
            repository: sl<VisitsRepository>(),
            locationService: sl<LocationService>(),
          ),
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
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, settings) {
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: settings.themeMode,
            routerConfig: router,
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
    );
  }
}
