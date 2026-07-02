import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/config/server_config_cubit.dart';
import '../l10n/generated/app_localizations.dart';
import '../shared/widgets/widgets.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/view/login_page.dart';
import '../features/auth/view/splash_page.dart';
import '../features/customers/data/models/customer.dart';
import '../features/customers/view/customer_detail_page.dart';
import '../features/customers/view/customers_list_page.dart';
import '../features/employees/data/models/employee.dart';
import '../features/home/view/home_shell.dart';
import '../features/nearby/view/nearby_map_page.dart';
import '../features/review/view/review_page.dart';
import '../features/server_config/view/server_setup_page.dart';
import '../features/settings/view/settings_page.dart';
import '../features/visits/data/models/visit.dart';
import '../features/visits/view/create_visit_page.dart';
import '../features/visits/view/visit_detail_page.dart';
import 'transitions.dart';

GoRouter buildRouter(AuthBloc authBloc, ServerConfigCubit serverConfigCubit) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _RouterRefresh([authBloc.stream, serverConfigCubit.stream]),
    redirect: (context, state) {
      final status = authBloc.state.status;
      final loc = state.matchedLocation;

      // Gate everything behind server configuration: until the user has saved
      // a backend URL, the only reachable screen is the setup page.
      if (!serverConfigCubit.state.isConfigured) {
        return loc == '/setup' ? null : '/setup';
      }

      if (status == AuthStatus.unknown) {
        return loc == '/' ? null : '/';
      }
      if (status == AuthStatus.unauthenticated ||
          status == AuthStatus.authenticating) {
        // On launch, land on the server screen first (it then continues to
        // /login). /login stays reachable so we don't bounce off it once the
        // user has moved on from setup.
        return (loc == '/login' || loc == '/setup') ? null : '/setup';
      }
      // Note: /setup is intentionally excluded here. While the user is changing
      // the server we clear their session, and we don't want a stale
      // "authenticated" state to bounce them to /home before that completes.
      if (status == AuthStatus.authenticated &&
          (loc == '/login' || loc == '/')) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (_, state) =>
            fadeTransition(state, const SplashPage()),
      ),
      GoRoute(
        path: '/setup',
        pageBuilder: (_, state) =>
            fadeTransition(state, const ServerSetupPage()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) =>
            fadeTransition(state, const LoginPage()),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (_, state) =>
            fadeTransition(state, const HomeShell()),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (_, state) =>
            slideTransition(state, const SettingsPage()),
      ),
      GoRoute(
        path: '/review',
        pageBuilder: (_, state) =>
            slideTransition(state, const ReviewPage()),
      ),
      GoRoute(
        path: '/customers',
        pageBuilder: (_, state) => slideTransition(
          state,
          Builder(
            builder: (context) => Scaffold(
              appBar: CvSubAppBar(
                title: AppLocalizations.of(context).customersTitle,
                eyebrow: AppLocalizations.of(context).roleManagerTitle,
                topInset: MediaQuery.paddingOf(context).top,
              ),
              body: const CustomersListPage(),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/customers/:id',
        pageBuilder: (_, state) {
          final id = int.parse(state.pathParameters['id']!);
          final fallback = state.extra is Customer ? state.extra as Customer : null;
          return slideTransition(
            state,
            CustomerDetailPage(customerId: id, fallback: fallback),
          );
        },
      ),
      GoRoute(
        path: '/customers/:id/nearby',
        pageBuilder: (_, state) {
          final id = int.parse(state.pathParameters['id']!);
          final customer = state.extra is Customer ? state.extra as Customer : null;
          return slideTransition(
            state,
            NearbyMapPage(customerId: id, customer: customer),
          );
        },
      ),
      GoRoute(
        path: '/visits/create',
        pageBuilder: (_, state) {
          final extra =
              state.extra is Map ? state.extra as Map<dynamic, dynamic> : null;
          final preEmployee =
              extra?['employee'] is Employee ? extra!['employee'] as Employee : null;
          return slideTransition(
            state,
            CreateVisitPage(preselectedEmployee: preEmployee),
          );
        },
      ),
      GoRoute(
        path: '/visits/:id',
        pageBuilder: (_, state) {
          final id = int.parse(state.pathParameters['id']!);
          final initial = state.extra is Visit ? state.extra as Visit : null;
          return slideTransition(
            state,
            VisitDetailPage(visitId: id, initial: initial),
          );
        },
      ),
    ],
  );
}

/// Re-runs the router redirect whenever any of the given streams emit
/// (auth state changes or the server config being saved/cleared).
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(List<Stream<dynamic>> streams) {
    for (final stream in streams) {
      _subs.add(stream.listen((_) => notifyListeners()));
    }
  }
  final List<StreamSubscription<dynamic>> _subs = [];

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }
}
