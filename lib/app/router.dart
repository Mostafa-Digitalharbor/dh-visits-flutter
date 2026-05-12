import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/view/login_page.dart';
import '../features/auth/view/splash_page.dart';
import '../features/customers/data/models/customer.dart';
import '../features/customers/view/customer_detail_page.dart';
import '../features/employees/data/models/employee.dart';
import '../features/home/view/home_shell.dart';
import '../features/nearby/view/nearby_map_page.dart';
import '../features/settings/view/settings_page.dart';
import '../features/visits/data/models/visit.dart';
import '../features/visits/view/create_visit_page.dart';
import '../features/visits/view/visit_detail_page.dart';
import 'transitions.dart';

GoRouter buildRouter(AuthBloc authBloc) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthListenable(authBloc),
    redirect: (context, state) {
      final status = authBloc.state.status;
      final loc = state.matchedLocation;

      if (status == AuthStatus.unknown) {
        return loc == '/' ? null : '/';
      }
      if (status == AuthStatus.unauthenticated ||
          status == AuthStatus.authenticating) {
        return loc == '/login' ? null : '/login';
      }
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
          final preCustomer =
              extra?['customer'] is Customer ? extra!['customer'] as Customer : null;
          final preEmployee =
              extra?['employee'] is Employee ? extra!['employee'] as Employee : null;
          return slideTransition(
            state,
            CreateVisitPage(
              preselectedCustomer: preCustomer,
              preselectedEmployee: preEmployee,
            ),
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

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(AuthBloc bloc) {
    _sub = bloc.stream.listen((_) => notifyListeners());
  }
  late final dynamic _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
