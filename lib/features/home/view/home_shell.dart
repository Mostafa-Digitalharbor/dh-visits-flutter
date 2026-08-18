import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/network/pending_actions_queue.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../analytics/view/analytics_page.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../visits/data/visits_repository.dart';
import '../../dashboard/view/dashboard_page.dart';
import '../../live_location/bloc/live_location_bloc.dart';
import '../../live_location/view/live_location_banner.dart';
import '../../profile/view/profile_page.dart';
import '../../route/view/route_page.dart';
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
  StreamSubscription<int>? _syncedSub;
  StreamSubscription<DroppedAction>? _droppedSub;

  @override
  void initState() {
    super.initState();
    final queue = sl<PendingActionsQueue>();

    // A queued offline action finally reached the server — pull the real state
    // back so the list stops showing the optimistic local one.
    _syncedSub = queue.onSynced.listen((_) {
      if (!mounted) return;
      context.read<VisitsListBloc>().add(const VisitsListLoadRequested());
    });

    // The server refused it. The user was told this was saved, so say plainly
    // that it wasn't and what to do — silence here loses GPS-stamped work.
    _droppedSub = queue.onDropped.listen((dropped) {
      if (!mounted) return;
      context.showSnack(
        context.s.offlineActionDropped(dropped.error.localize(context)),
        kind: SnackKind.error,
      );
      context.read<VisitsListBloc>().add(const VisitsListLoadRequested());
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthBloc>().state.user;
      final isManager = user?.canEditVisits ?? false;
      // Their permissions never loaded, so the workflow buttons won't appear.
      // Say why — otherwise the app just looks broken or their account revoked.
      if (user?.profileIncomplete == true) {
        context.showSnack(
          context.s.errProfileIncomplete,
          kind: SnackKind.error,
        );
      }
      context
          .read<LiveLocationBloc>()
          .add(const LiveLocationStartRequested());
      // Only try to resume an active visit for field users — admins
      // don't go on visits, so any "active" visit in the system would
      // belong to another user and end up misrepresented on their bar.
      if (!isManager) {
        context.read<VisitBloc>().add(const VisitResumeRequested());
      }
      context.read<VisitsListBloc>().add(VisitsListLoadRequested(
            scope:
                isManager ? VisitListScope.pending : VisitListScope.mine,
          ));
    });
  }

  @override
  void dispose() {
    _syncedSub?.cancel();
    _droppedSub?.cancel();
    super.dispose();
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
          ? const _ManagerShell()
          : const _UserShell(),
    );
  }
}

/// One tab of a role shell.
class _Tab {
  final IconData icon;
  final String label;
  final Widget page;

  /// Shown as the app-bar title while this tab is selected. Usually longer than
  /// [label], which has to fit under a nav icon.
  final String title;

  const _Tab({
    required this.icon,
    required this.label,
    required this.title,
    required this.page,
  });
}

/// The chrome both role shells share: app bar, the two status banners, a lazy
/// tab stack and the bottom navigation.
///
/// The employee and manager shells were two 100-line `Scaffold`s that differed
/// only in their tab list, which app-bar chips they showed, whether the
/// active-visit bar was present, and what happened on a tab switch. Keeping
/// them apart meant every layout fix (the banners, the FAB placement, the
/// text-scale-aware bar height) had to be made twice — and typically wasn't.
class _RoleShell extends StatefulWidget {
  final List<_Tab> tabs;

  /// Tab index that offers "create visit"; `null` for none.
  final int? fabTab;

  /// Unique across the two shells: two `FloatingActionButton`s with the same
  /// hero tag on screen at once throws.
  final String fabHeroTag;

  /// Whether the active-visit bar sits above the nav (field users only —
  /// managers don't go on visits).
  final bool showVisitBar;

  /// Fired after the index changes, so a shell can refetch what just came into
  /// view.
  final ValueChanged<int>? onTabSelected;

  const _RoleShell({
    required this.tabs,
    required this.fabHeroTag,
    this.fabTab,
    this.showVisitBar = false,
    this.onTabSelected,
  });

  @override
  State<_RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<_RoleShell> {
  int _tab = 0;

  void _select(int i) {
    if (i != _tab) {
      HapticFeedback.selectionClick();
      setState(() => _tab = i);
    }
    widget.onTabSelected?.call(i);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = widget.tabs;
    return Scaffold(
      appBar: _AppBar(
        title: tabs[_tab].title,
        topInset: MediaQuery.paddingOf(context).top,
        textScale: context.textScale,
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          const LiveLocationBanner(),
          Expanded(
            child: LazyIndexedStack(
              index: _tab,
              children: [for (final t in tabs) t.page],
            ),
          ),
        ],
      ),
      floatingActionButton: _tab == widget.fabTab
          ? FloatingActionButton.extended(
              heroTag: widget.fabHeroTag,
              onPressed: () => context.push(AppRoutes.createVisit),
              icon: const Icon(Symbols.add),
              label: Text(context.s.createVisitTooltip),
            )
          : null,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showVisitBar)
            PersistentVisitBar(
              onTap: () {
                final active = context.read<VisitBloc>().state.activeVisit;
                if (active != null) {
                  context.push(AppRoutes.visitDetail(active.id), extra: active);
                }
              },
            ),
          NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: _select,
            destinations: [
              for (final t in tabs)
                NavigationDestination(
                  icon: Icon(t.icon),
                  selectedIcon: Icon(t.icon, fill: 1),
                  label: t.label,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Employee layout: three-tab shell {زياراتي · مسار اليوم · حسابي}
/// (design flows §3). The persistent active-visit bar floats above the nav.
class _UserShell extends StatelessWidget {
  const _UserShell();

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return _RoleShell(
      // Field employees can plan their own visits (guide §2), from the My
      // Visits tab only.
      fabTab: 0,
      fabHeroTag: 'create-visit-user-hero',
      showVisitBar: true,
      tabs: [
        _Tab(
          icon: Symbols.list_alt,
          label: s.visitsTabTitle,
          title: s.visitsListTitle,
          page: const VisitsListPage(),
        ),
        _Tab(
          icon: Symbols.route,
          label: s.routeTabTitle,
          title: s.routeTabTitle,
          page: const RoutePage(),
        ),
        _profileTab(s),
      ],
    );
  }
}

/// The account tab, identical in both shells — same icon, label and body, so
/// the two role layouts differ only in the tabs that are actually role-specific.
_Tab _profileTab(AppLocalizations s) => _Tab(
      icon: Symbols.person,
      label: s.profileTabTitle,
      title: s.profileTitle,
      page: const ProfileView(),
    );

/// Manager layout: four-tab shell
/// {لوحة التحكم · زيارات الفريق · التحليلات · حسابي} with a FAB to create
/// visits on the visits tab.
class _ManagerShell extends StatefulWidget {
  const _ManagerShell();

  @override
  State<_ManagerShell> createState() => _ManagerShellState();
}

class _ManagerShellState extends State<_ManagerShell> {
  static const _dashboardTab = 0;
  static const _visitsTab = 1;
  static const _analyticsTab = 2;

  // Dashboard & Analytics need the FULL team dataset, so they get their own
  // `team`-scoped blocs — independent of the list tab, whose scope changes as
  // the manager switches pending/team/escalated chips.
  //
  // Held here rather than created inline in the tab stack so that switching
  // tabs can refetch them. The stack keeps each child alive once built, so a
  // manager who approved a visit on the list tab came back to a Dashboard
  // still showing the pre-approval counts — and Analytics, which has no
  // pull-to-refresh, could not be corrected at all without restarting the app.
  late final VisitsListBloc _dashboardBloc;
  late final VisitsListBloc _analyticsBloc;

  @override
  void initState() {
    super.initState();
    _dashboardBloc = VisitsListBloc(repository: sl<VisitsRepository>())
      ..add(const VisitsListLoadRequested(scope: VisitListScope.team));
    // Not loaded upfront: Analytics reads the same `team` slice as the
    // dashboard and is three taps away at launch, so fetching it during the
    // login burst just adds a request to the slowest moment in the app. The
    // tab loads itself the first time it is opened (see [_onTabSelected]).
    _analyticsBloc = VisitsListBloc(repository: sl<VisitsRepository>());
  }

  @override
  void dispose() {
    _dashboardBloc.close();
    _analyticsBloc.close();
    super.dispose();
  }

  /// Refetch the tab being opened, so its numbers reflect any workflow action
  /// taken while it was off-screen.
  void _onTabSelected(int i) {
    const reload = VisitsListLoadRequested(scope: VisitListScope.team);
    if (i == _dashboardTab) _dashboardBloc.add(reload);
    if (i == _analyticsTab) _analyticsBloc.add(reload);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return _RoleShell(
      fabTab: _visitsTab,
      fabHeroTag: 'create-visit-hero',
      onTabSelected: _onTabSelected,
      tabs: [
        _Tab(
          icon: Symbols.dashboard,
          label: s.dashboardTabTitle,
          title: s.dashboardTabTitle,
          page: BlocProvider.value(
            value: _dashboardBloc,
            child: const DashboardPage(),
          ),
        ),
        _Tab(
          icon: Symbols.list_alt,
          label: s.visitsTabTitle,
          title: s.visitsListTitle,
          page: const VisitsListPage(),
        ),
        _Tab(
          icon: Symbols.insights,
          label: s.analyticsTabTitle,
          title: s.analyticsTabTitle,
          page: BlocProvider.value(
            value: _analyticsBloc,
            child: const AnalyticsPage(),
          ),
        ),
        _profileTab(s),
      ],
    );
  }
}

/// Redesigned top bar (design `02-components.md §8 — CvAppBar`): gradient logo
/// mark + eyebrow (role) + title, then action chips on the trailing edge.
class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;

  /// The device status-bar inset (`MediaQuery.padding.top`) so the bar's
  /// declared [preferredSize] matches the space it actually paints — keeps the
  /// title from being pushed below its slot on notched / status-bar devices.
  final double topInset;

  /// The active OS text-scale, captured at construction so the bar can grow its
  /// fixed height in step with the eyebrow + title it wraps. A `PreferredSize`
  /// getter has no `BuildContext`, so the value must be threaded in.
  final double textScale;

  const _AppBar({
    this.title,
    this.topInset = 0,
    this.textScale = 1.0,
  });

  /// Eyebrow (~13dp) + title (~22dp) lines grown by the OS font scale, plus the
  /// 20dp of vertical padding the bar paints around them.
  double get _barHeight => 24 + 34 * textScale.clamp(1.0, 1.25);

  @override
  Size get preferredSize => Size.fromHeight(_barHeight + topInset);

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    final user = context.watch<AuthBloc>().state.user;
    final eyebrow = (user?.canEditVisits ?? false)
        ? context.s.roleManagerTitle
        : context.s.roleEmployeeTitle;

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
                  borderRadius: BorderRadius.circular(Radii.sm),
                  boxShadow: x.elev1,
                ),
                alignment: Alignment.center,
                child: Image.asset(AppAssets.logoMark,
                    width: 24, height: 24, color: Colors.white),
              ),
              context.gapW(Insets.x3),
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
                            fontSize: FontSz.xs,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: cs.onSurfaceVariant)),
                    Text(title ?? context.s.appTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: FontSz.appBar,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: cs.onSurface)),
                  ],
                ),
              ),
              // Notifications is the only action left up here. Customers and
              // settings both moved into the Profile tab: they are places you
              // go, not things you do to the screen you are on, and a bar that
              // mixed the two grew a chip per feature. Customers survives as a
              // row in the manager's profile, where it already was.
              const _NotificationChip(),
            ],
          ),
        ),
    );
  }
}

/// Bell action chip with an unread badge, backed by the current user's pending
/// visit activities ([VisitsRepository.myActivityCount]). Refreshes its count
/// when the app returns to the foreground and after visiting the feed.
class _NotificationChip extends StatefulWidget {
  const _NotificationChip();

  @override
  State<_NotificationChip> createState() => _NotificationChipState();
}

class _NotificationChipState extends State<_NotificationChip>
    with WidgetsBindingObserver {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    try {
      final c = await sl<VisitsRepository>().myActivityCount();
      if (mounted) setState(() => _count = c);
    } catch (_) {
      // Best-effort: a failed count must not break the app bar.
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconActionChip(
          icon: Symbols.notifications,
          tooltip: context.s.wfNotificationsTitle,
          onTap: () async {
            await context.push(AppRoutes.notifications);
            _load();
          },
        ),
        if (_count > 0)
          // PositionedDirectional so the unread badge mirrors in Arabic, the
          // way it already does on the settings and analytics screens.
          PositionedDirectional(
            end: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: BoxDecoration(
                color: cs.error,
                borderRadius: BorderRadius.circular(Radii.pill),
                border: Border.all(color: cs.surfaceContainerLowest, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                _count > 99 ? '99+' : '$_count',
                style: TextStyle(
                  color: cs.onError,
                  fontSize: FontSz.tiny,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

