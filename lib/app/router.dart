import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/config/server_config_cubit.dart';
import '../shared/extensions/context_extensions.dart';
import '../shared/widgets/widgets.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/view/login_page.dart';
import '../features/auth/view/splash_page.dart';
import '../features/customers/data/models/customer.dart';
import '../features/customers/view/customer_detail_page.dart';
import '../features/customers/view/customers_list_page.dart';
import '../features/employees/data/models/employee.dart';
import '../features/home/view/home_shell.dart';
import '../features/notifications/view/notifications_page.dart';
import '../features/review/view/review_page.dart';
import '../features/server_config/view/server_setup_page.dart';
import '../features/visits/data/models/visit.dart';
import '../features/visits/view/create_visit_page.dart';
import '../features/visits/view/visit_detail_page.dart';
import '../features/visits/view/visit_trail_page.dart';
import 'routes.dart';
import 'transitions.dart';

GoRouter buildRouter(AuthBloc authBloc, ServerConfigCubit serverConfigCubit) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _RouterRefresh([authBloc.stream, serverConfigCubit.stream]),
    // An unknown path (a stale or mistyped link): a localized page with a way
    // home, instead of go_router's English debug screen.
    errorPageBuilder: (_, state) => fadeTransition(state, const _NotFoundPage()),
    redirect: (context, state) {
      final status = authBloc.state.status;
      final loc = state.matchedLocation;

      // Gate everything behind server configuration: until the user has saved
      // a backend URL, the only reachable screen is the setup page.
      if (!serverConfigCubit.state.isConfigured) {
        return loc == AppRoutes.setup ? null : AppRoutes.setup;
      }

      if (status == AuthStatus.unknown) {
        return loc == AppRoutes.splash ? null : AppRoutes.splash;
      }
      if (status == AuthStatus.unauthenticated ||
          status == AuthStatus.authenticating) {
        if (loc == AppRoutes.login || loc == AppRoutes.setup) return null;
        // Coming off the splash is a cold start: the server screen is the first
        // thing the app asks for, whether or not one is already saved, and
        // /login is one "continue" away (with a back chip to return here).
        //
        // Any other origin is a session that just *ended* — a sign-out, or a
        // 401 from mid-task — where the server was never in question; making
        // those re-confirm the URL was pure friction, so they go to /login.
        return loc == AppRoutes.splash ? AppRoutes.setup : AppRoutes.login;
      }
      // Note: /setup is intentionally excluded here. While the user is changing
      // the server we clear their session, and we don't want a stale
      // "authenticated" state to bounce them to /home before that completes.
      if (status == AuthStatus.authenticated &&
          (loc == AppRoutes.login || loc == AppRoutes.splash)) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (_, state) =>
            fadeTransition(state, const SplashPage()),
      ),
      GoRoute(
        path: AppRoutes.setup,
        pageBuilder: (_, state) =>
            fadeTransition(state, const ServerSetupPage()),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (_, state) =>
            fadeTransition(state, const LoginPage()),
      ),
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: (_, state) =>
            fadeTransition(state, const HomeShell()),
      ),
      GoRoute(
        path: AppRoutes.review,
        pageBuilder: (_, state) =>
            slideTransition(state, const ReviewPage()),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        pageBuilder: (_, state) =>
            slideTransition(state, const NotificationsPage()),
      ),
      GoRoute(
        path: AppRoutes.customers,
        pageBuilder: (_, state) => slideTransition(
          state,
          Builder(
            builder: (context) => Scaffold(
              appBar: CvSubAppBar(
                title: context.s.customersTitle,
                eyebrow: context.s.roleManagerTitle,
                topInset: MediaQuery.paddingOf(context).top,
              ),
              body: const CustomersListPage(),
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.customerDetailPath,
        pageBuilder: (_, state) => _withId(state, (id) {
          final fallback = state.extra is Customer ? state.extra as Customer : null;
          return slideTransition(
            state,
            CustomerDetailPage(customerId: id, fallback: fallback),
          );
        }),
      ),
      GoRoute(
        path: AppRoutes.createVisit,
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
        path: AppRoutes.visitDetailPath,
        pageBuilder: (_, state) => _withId(state, (id) {
          final initial = state.extra is Visit ? state.extra as Visit : null;
          return slideTransition(
            state,
            VisitDetailPage(visitId: id, initial: initial),
          );
        }),
      ),
      GoRoute(
        path: AppRoutes.visitTrailPath,
        pageBuilder: (_, state) => _withId(state, (id) {
          // The visit travels as `extra`: the trail page needs its state (is it
          // still running?) to decide whether to poll, and re-reading the
          // record here just to learn that would put a spinner in front of a
          // map we can already draw. A direct hit with no `extra` — a pasted
          // link — has nothing to show, so it bounces to the detail page, which
          // knows how to load the visit and offers the trail from there.
          final visit = state.extra is Visit ? state.extra as Visit : null;
          if (visit == null) {
            return slideTransition(state, VisitDetailPage(visitId: id));
          }
          return slideTransition(state, VisitTrailPage(visit: visit));
        }),
      ),
    ],
  );
}

/// The route's `:id`, handed to [build] — or the not-found page when the path
/// carries something that isn't a record id (`/visits/abc`), which used to
/// throw a FormatException out of the page builder.
Page<void> _withId(GoRouterState state, Page<void> Function(int id) build) {
  final id = int.tryParse(state.pathParameters[_idParam] ?? '');
  if (id == null || id <= 0) {
    return fadeTransition(state, const _NotFoundPage());
  }
  return build(id);
}

const _idParam = 'id';

class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage();

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      appBar: CvSubAppBar(
        title: s.commonPageNotFoundTitle,
        topInset: MediaQuery.paddingOf(context).top,
      ),
      body: ErrorView(
        icon: Icons.link_off_rounded,
        message: s.commonPageNotFoundMessage,
        actionLabel: s.commonGoHome,
        actionIcon: Icons.home_outlined,
        onRetry: () => context.go(AppRoutes.home),
      ),
    );
  }
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
