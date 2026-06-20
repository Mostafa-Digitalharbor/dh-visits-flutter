import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../analytics/view/analytics_page.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../dashboard/view/dashboard_page.dart';
import '../../live_location/bloc/live_location_bloc.dart';
import '../../route/view/route_page.dart';
import '../../settings/view/settings_page.dart';
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

/// Employee layout: three-tab shell {زياراتي · مسار اليوم · الإعدادات}
/// (design flows §3). The persistent active-visit bar floats above the nav.
class _UserShell extends StatefulWidget {
  final _HomeShellState state;
  const _UserShell({required this.state});

  @override
  State<_UserShell> createState() => _UserShellState();
}

class _UserShellState extends State<_UserShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final titles = [
      context.s.visitsListTitle,
      context.s.routeTabTitle,
      context.s.settingsTitle,
    ];
    return Scaffold(
      appBar: _AppBar(
        title: titles[_tab],
        showSettings: false,
        topInset: MediaQuery.of(context).padding.top,
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: const [VisitsListPage(), RoutePage(), SettingsView()],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PersistentVisitBar(onTap: _noop),
          NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) {
              HapticFeedback.selectionClick();
              setState(() => _tab = i);
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(Symbols.list_alt),
                selectedIcon: const Icon(Symbols.list_alt, fill: 1),
                label: context.s.visitsTabTitle,
              ),
              NavigationDestination(
                icon: const Icon(Symbols.route),
                selectedIcon: const Icon(Symbols.route, fill: 1),
                label: context.s.routeTabTitle,
              ),
              NavigationDestination(
                icon: const Icon(Symbols.settings),
                selectedIcon: const Icon(Symbols.settings, fill: 1),
                label: context.s.settingsTitle,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static void _noop() {}
}

/// Manager layout: three-tab shell {لوحة التحكم · زيارات الفريق · التحليلات}
/// with a FAB to create visits on the visits tab, and groups/settings action
/// chips in the app bar.
class _ManagerShell extends StatefulWidget {
  final _HomeShellState state;
  const _ManagerShell({required this.state});

  @override
  State<_ManagerShell> createState() => _ManagerShellState();
}

class _ManagerShellState extends State<_ManagerShell> {
  int _tabIndex = 0; // 0 dashboard · 1 visits · 2 analytics

  @override
  Widget build(BuildContext context) {
    final isVisits = _tabIndex == 1;
    final titles = [
      context.s.dashboardTabTitle,
      context.s.visitsListTitle,
      context.s.analyticsTabTitle,
    ];
    return Scaffold(
      appBar: _AppBar(
        title: titles[_tabIndex],
        showGroups: true,
        topInset: MediaQuery.of(context).padding.top,
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: const [
                DashboardPage(),
                VisitsListPage(),
                AnalyticsPage(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: isVisits
          ? FloatingActionButton.extended(
              heroTag: 'create-visit-hero',
              onPressed: () => context.push('/visits/create'),
              icon: const Icon(Symbols.add),
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
            icon: const Icon(Symbols.dashboard),
            selectedIcon: const Icon(Symbols.dashboard, fill: 1),
            label: context.s.dashboardTabTitle,
          ),
          NavigationDestination(
            icon: const Icon(Symbols.list_alt),
            selectedIcon: const Icon(Symbols.list_alt, fill: 1),
            label: context.s.visitsTabTitle,
          ),
          NavigationDestination(
            icon: const Icon(Symbols.insights),
            selectedIcon: const Icon(Symbols.insights, fill: 1),
            label: context.s.analyticsTabTitle,
          ),
        ],
      ),
    );
  }
}

/// Redesigned top bar (design `02-components.md §8 — CvAppBar`): gradient logo
/// mark + eyebrow (role) + title, then action chips on the trailing edge.
class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final bool showGroups;
  final bool showSettings;

  /// The device status-bar inset (`MediaQuery.padding.top`) so the bar's
  /// declared [preferredSize] matches the space it actually paints — keeps the
  /// title from being pushed below its slot on notched / status-bar devices.
  final double topInset;

  const _AppBar({
    this.title,
    this.showGroups = false,
    this.showSettings = true,
    this.topInset = 0,
  });

  static const double _barHeight = 60;

  @override
  Size get preferredSize => Size.fromHeight(_barHeight + topInset);

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    final user = context.watch<AuthBloc>().state.user;
    final eyebrow =
        (user?.canEditVisits ?? false) ? context.s.roleManager : context.s.roleUser;

    return Material(
      color: cs.surfaceContainerLowest,
      child: Container(
          height: _barHeight + topInset,
          padding: EdgeInsets.fromLTRB(14, 10 + topInset, 14, 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: x.outlineVariant)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: x.avatarGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: x.elev1,
                ),
                alignment: Alignment.center,
                child: Image.asset('assets/images/logo-d.png',
                    width: 24, height: 24, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(eyebrow,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: cs.onSurfaceVariant)),
                    Text(title ?? context.s.appTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 19,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: cs.onSurface)),
                  ],
                ),
              ),
              if (showGroups) ...[
                _ActionChip(
                  icon: Symbols.groups,
                  tooltip: context.s.customersTitle,
                  onTap: () => context.push('/customers'),
                ),
                const SizedBox(width: 8),
              ],
              if (showSettings)
                _ActionChip(
                  icon: Symbols.settings,
                  tooltip: context.s.settingsTitle,
                  onTap: () => context.push('/settings'),
                ),
            ],
          ),
        ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _ActionChip({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: x.outlineVariant),
            boxShadow: x.elev1,
          ),
          child: Icon(icon, size: 21, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}
