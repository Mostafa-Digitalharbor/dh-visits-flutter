import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../dashboard/view/dashboard_page.dart';
import '../../live_location/bloc/live_location_bloc.dart';
import '../../visits/bloc/visit_bloc.dart';
import '../../visits/bloc/visits_list_bloc.dart';
import '../../visits/view/persistent_visit_bar.dart';
import '../../visits/view/visits_list_page.dart';

/// Root shell after login. Branches on the user's role:
///
/// - **Manager** (`canEditVisits == true`): keeps the multi-tab layout
///   (Customers + Visits) so they can browse customers and oversee visits.
/// - **User** (`canEditVisits == false`): just the visits list (their
///   today-by-default queue). No bottom nav, simplified AppBar.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthBloc>().state.user;
      final isManager = user?.canEditVisits ?? false;
      context
          .read<LiveLocationBloc>()
          .add(const LiveLocationStartRequested());
      // Only try to resume an active visit for field users — admins
      // don't go on visits, so any "active" visit in the system would
      // belong to another user and end up misrepresented on their bar.
      if (!isManager) {
        context.read<VisitBloc>().add(const VisitResumeRequested());
      }
      context
          .read<VisitsListBloc>()
          .add(VisitsListLoadRequested(includeDrafts: isManager));
    });
  }

  Future<void> _confirmExit(BuildContext context) async {
    final shouldExit = await ConfirmDialog.show(
      context,
      title: context.s.confirmExitTitle,
      message: context.s.confirmExitMessage,
      icon: Icons.exit_to_app_rounded,
    );
    if (shouldExit) {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthBloc>().state.user;
    final isManager = user?.canEditVisits ?? false;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _confirmExit(context);
      },
      child: isManager
          ? _ManagerShell(state: this)
          : _UserShell(state: this),
    );
  }
}

/// User layout: single Visits screen, simplified app bar, no bottom nav.
class _UserShell extends StatelessWidget {
  final _HomeShellState state;
  const _UserShell({required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const _AppBar(),
      body: const Column(
        children: [
          OfflineBanner(),
          Expanded(child: VisitsListPage()),
        ],
      ),
      bottomNavigationBar: const PersistentVisitBar(onTap: _noop),
    );
  }

  static void _noop() {}
}

/// Manager layout: two-tab shell (Visits + Dashboard) with a FAB to
/// create new visits. The Visits tab keeps the existing list; the
/// Dashboard tab is the new admin overview. No PersistentVisitBar —
/// admins don't go on visits themselves, so a "running visit"
/// indicator at the bottom would just surface someone else's
/// work-in-progress.
class _ManagerShell extends StatefulWidget {
  final _HomeShellState state;
  const _ManagerShell({required this.state});

  @override
  State<_ManagerShell> createState() => _ManagerShellState();
}

class _ManagerShellState extends State<_ManagerShell> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isVisits = _tabIndex == 0;
    return Scaffold(
      appBar: _AppBar(
        title: isVisits
            ? context.s.visitsListTitle
            : context.s.dashboardTabTitle,
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: const [
                VisitsListPage(),
                DashboardPage(),
              ],
            ),
          ),
        ],
      ),
      // FAB is only meaningful on the Visits tab. Hide it on the
      // Dashboard so the bottom-right corner stays clean.
      floatingActionButton: isVisits
          ? FloatingActionButton.extended(
              heroTag: 'create-visit-hero',
              onPressed: () => context.push('/visits/create'),
              icon: const Icon(Icons.add),
              label: Text(context.s.createVisitTooltip),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) {
          HapticFeedback.selectionClick();
          setState(() => _tabIndex = i);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.list_alt_rounded),
            label: context.s.visitsTabTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.dashboard_rounded),
            label: context.s.dashboardTabTitle,
          ),
        ],
      ),
    );
  }
}

class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  const _AppBar({this.title});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            padding: const EdgeInsets.all(3),
            child: ClipOval(
              child: Image.asset(
                'assets/images/logo.jpg',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title ?? context.s.appTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: context.s.settingsTitle,
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.push('/settings'),
        ),
      ],
    );
  }
}
