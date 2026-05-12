import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../employees/view/employees_list_page.dart';
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
      context
          .read<LiveLocationBloc>()
          .add(const LiveLocationStartRequested());
      context.read<VisitBloc>().add(const VisitResumeRequested());
      context
          .read<VisitsListBloc>()
          .add(const VisitsListLoadRequested());
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
      child: isManager ? _ManagerShell(state: this) : _UserShell(state: this),
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
      body: const VisitsListPage(),
      bottomNavigationBar: const PersistentVisitBar(onTap: _noop),
    );
  }

  static void _noop() {}
}

/// Manager layout: Customers + Visits tabs. Visits tab uses the new list
/// (no more dedicated Active / History split — the persistent bar covers
/// the live-timer affordance and active visits float to the top).
class _ManagerShell extends StatefulWidget {
  final _HomeShellState state;
  const _ManagerShell({required this.state});

  @override
  State<_ManagerShell> createState() => _ManagerShellState();
}

class _ManagerShellState extends State<_ManagerShell> {
  int _index = 0;

  static const List<Widget> _pages = [
    VisitsListPage(),
    EmployeesListPage(),
  ];

  String _title(BuildContext context) {
    switch (_index) {
      case 0:
        return context.s.visitsListTitle;
      case 1:
        return context.s.employeesTitle;
      default:
        return context.s.appTitle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<VisitBloc, VisitState>(
      // When the user just checked-in, snap to the Visits tab so they see
      // the running visit at the top of the list (and the persistent bar).
      listenWhen: (prev, curr) =>
          prev.status != VisitStatus.checkedIn &&
          curr.status == VisitStatus.checkedIn,
      listener: (context, state) {
        if (_index != 0) setState(() => _index = 0);
      },
      child: Scaffold(
        appBar: _AppBar(title: _title(context)),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: KeyedSubtree(
            key: ValueKey(_index),
            child: _pages[_index],
          ),
        ),
        floatingActionButton: _index == 0
            ? FloatingActionButton.extended(
                onPressed: () => context.push('/visits/create'),
                icon: const Icon(Icons.add),
                label: Text(context.s.createVisitTooltip),
              )
            : null,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PersistentVisitBar(onTap: () => setState(() => _index = 0)),
            NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.event_note_outlined),
                  selectedIcon: const Icon(Icons.event_note),
                  label: context.s.visitsListTitle,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.badge_outlined),
                  selectedIcon: const Icon(Icons.badge),
                  label: context.s.employeesTitle,
                ),
              ],
            ),
          ],
        ),
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
