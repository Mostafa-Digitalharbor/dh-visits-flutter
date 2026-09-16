import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/constants.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/network/pending_actions_queue.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/utils/app_number.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../analytics/view/analytics_page.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../dashboard/view/dashboard_page.dart';
import '../../profile/view/profile_page.dart';
import '../../route/view/route_page.dart';
import '../../visits/bloc/visit_bloc.dart';
import '../../visits/bloc/visits_list_bloc.dart';
import '../../visits/data/visit_tracking_consent.dart';
import '../../visits/data/visit_trail_tracker.dart';
import '../../visits/data/visits_repository.dart';
import '../../visits/view/persistent_visit_bar.dart';
import '../../visits/view/visit_tracking_disclosure_dialog.dart';
import '../../visits/view/visits_list_page.dart';

/// Root shell after login. Branches on the user's role:
///
/// - **Manager** (`canEditVisits == true`): dashboard, team visits, analytics
///   and profile.
/// - **User** (`canEditVisits == false`): their own visits, today's route and
///   profile, with the active-visit bar above the navigation.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  StreamSubscription<SyncedAction>? _syncedSub;
  StreamSubscription<DroppedAction>? _droppedSub;
  StreamSubscription<int>? _trailDroppedSub;
  VisitTrailTracker? _tracker;

  /// The disclosure is offered at most once per session for a visit restored
  /// without consent; after a "Not now" the active-visit bar offers it again.
  bool _consentOffered = false;

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

    // Same promise as above, for the GPS trail: positions were recorded on the
    // device and the server then refused them for good (a fix stamped outside
    // the visit's start-end window, most often). The rep believes their route
    // is on the record, so the gap in it has to be said out loud.
    final tracker = slMaybe<VisitTrailTracker>();
    _trailDroppedSub = tracker?.onPointsDropped.listen((count) {
      if (!mounted || count <= 0) return;
      context.showSnack(context.s.trailPointsDropped(count), kind: SnackKind.error);
    });

    // A visit already in progress (started on another device, or before this
    // install showed the disclosure) is recorded only after the disclosure.
    _tracker = tracker;
    tracker?.status.addListener(_onTrailStatus);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthBloc>().state.user;
      final isManager = user?.canEditVisits ?? false;
      // Their permissions never loaded, so the workflow buttons won't appear.
      // Say why — otherwise the app just looks broken or their account revoked.
      if (user?.profileIncomplete == true) {
        context.showSnack(context.s.errProfileIncomplete, kind: SnackKind.error);
      }
      // Restore the caller's own running visit for every role (and with it
      // its trail recording — only if the server still has it in progress).
      // `/api/visit/my` only ever returns visits where the caller is the
      // responsible employee, so a manager never picks up a subordinate's
      // visit here. The active-visit bar itself is shown in the field-user
      // shell only.
      context.read<VisitBloc>().add(const VisitResumeRequested());
      context.read<VisitsListBloc>().add(VisitsListLoadRequested(
            scope: isManager ? VisitListScope.pending : VisitListScope.mine,
          ));
    });
  }

  void _onTrailStatus() {
    final status = _tracker?.status.value;
    if (status?.paused != TrailPause.consent || _consentOffered) return;
    _consentOffered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final agreed = await VisitTrackingDisclosureDialog.ensureAccepted(
        context,
        VisitTrackingConsent(slMaybe<SharedPreferences>()),
      );
      if (agreed) {
        await _tracker?.retry();
      } else {
        appLog('[HomeShell] visit tracking disclosure declined');
      }
    });
  }

  @override
  void dispose() {
    _trailDroppedSub?.cancel();
    _tracker?.status.removeListener(_onTrailStatus);
    _syncedSub?.cancel();
    _droppedSub?.cancel();
    super.dispose();
  }

  Future<void> _confirmExit(BuildContext context) async {
    final shouldExit = await ConfirmDialog.show(
      context,
      title: context.s.confirmExitTitle,
      message: context.s.confirmExitMessage,
      icon: Symbols.exit_to_app,
      tone: DialogTone.neutral,
    );
    if (shouldExit) {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isManager = context.select<AuthBloc, bool>(
      (bloc) => bloc.state.user?.canEditVisits ?? false,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _confirmExit(context);
      },
      child: isManager ? const _ManagerShell() : const _UserShell(),
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

/// The chrome both role shells share: app bar, the status banners, a lazy
/// tab stack and the bottom navigation.
///
/// The employee and manager shells were two 100-line `Scaffold`s that differed
/// only in their tab list, which app-bar chips they showed, whether the
/// active-visit bar was present, and what happened on a tab switch. Keeping
/// them apart meant every layout fix (the banners, the FAB placement, the
/// text-scale-aware bar height) had to be made twice — and typically wasn't.
class _RoleShell extends StatefulWidget {
  final List<_Tab> tabs;

  /// The selected tab. Owned by the caller, so a shell can switch tabs itself
  /// (a dashboard tile opening the visits list).
  final ValueNotifier<int> selection;

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
    required this.selection,
    required this.fabHeroTag,
    this.fabTab,
    this.showVisitBar = false,
    this.onTabSelected,
  });

  @override
  State<_RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<_RoleShell> {
  void _select(int i) {
    if (i != widget.selection.value) {
      HapticFeedback.selectionClick();
      widget.selection.value = i;
    }
    widget.onTabSelected?.call(i);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = widget.tabs;
    // Read above the Scaffold: inside its body the keyboard inset is already
    // subtracted. With the keyboard up (searching a list), the stacked status
    // banners would leave a landscape phone no room for the list itself, so
    // they step aside until typing is done.
    final keyboardOpen = context.keyboardInset > 0;
    return ValueListenableBuilder<int>(
      valueListenable: widget.selection,
      builder: (context, tab, _) => Scaffold(
        appBar: _AppBar(
          title: tabs[tab].title,
          topInset: MediaQuery.paddingOf(context).top,
          textScale: context.textScale,
        ),
        body: Column(
          children: [
            if (!keyboardOpen) ...[
              const OfflineBanner(),
            ],
            Expanded(
              child: LazyIndexedStack(
                index: tab,
                children: [for (final t in tabs) t.page],
              ),
            ),
          ],
        ),
        floatingActionButton: tab == widget.fabTab
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
              selectedIndex: tab,
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
      ),
    );
  }
}

/// Employee layout: three-tab shell {زياراتي · مسار اليوم · حسابي}
/// (design flows §3). The persistent active-visit bar floats above the nav.
class _UserShell extends StatefulWidget {
  const _UserShell();

  @override
  State<_UserShell> createState() => _UserShellState();
}

class _UserShellState extends State<_UserShell> {
  final _selection = ValueNotifier(0);

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return _RoleShell(
      selection: _selection,
      // Field employees can plan their own visits (guide §2), from the My
      // Visits tab only.
      fabTab: 0,
      fabHeroTag: HeroTags.createVisitUser,
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

  final _selection = ValueNotifier(_dashboardTab);

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
    _selection.dispose();
    super.dispose();
  }

  /// Refetch the tab being opened, so its numbers reflect any workflow action
  /// taken while it was off-screen.
  void _onTabSelected(int i) {
    const reload = VisitsListLoadRequested(scope: VisitListScope.team);
    if (i == _dashboardTab) _dashboardBloc.add(reload);
    if (i == _analyticsTab) _analyticsBloc.add(reload);
  }

  /// A dashboard tile was tapped: show the team's visits narrowed to what the
  /// tile counted. The tile counts the whole team, so the list switches to the
  /// team scope before the preset is applied.
  void _openVisits(VisitsListFocus focus) {
    context.read<VisitsListBloc>()
      ..add(const VisitsListScopeChanged(VisitListScope.team))
      ..add(VisitsListFocusChanged(focus));
    _selection.value = _visitsTab;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return _RoleShell(
      selection: _selection,
      fabTab: _visitsTab,
      fabHeroTag: HeroTags.createVisitManager,
      onTabSelected: _onTabSelected,
      tabs: [
        _Tab(
          icon: Symbols.dashboard,
          label: s.dashboardTabTitle,
          title: s.dashboardTabTitle,
          page: BlocProvider.value(
            value: _dashboardBloc,
            child: DashboardPage(onOpenVisits: _openVisits),
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

  /// Vertical padding above and below the two text lines.
  static const double _padV = Insets.x2h;
  static const double _padH = Insets.x3h;

  /// The eyebrow (~13dp) and title (~22dp) lines at 1× text, less the 1dp the
  /// two share where their tight line heights overlap.
  static const double _textBlock = 34.0;

  /// Room for the bottom hairline and rounding, so the title never touches it.
  static const double _slack = Insets.x1;

  static const double _lineHeight = 1.15;
  static const double _eyebrowTracking = 0.3;
  static const double _titleTracking = -0.2;

  /// The fixed chrome plus the text block, grown by the OS font scale — the
  /// same growth `context.fixedH` applies, which a `PreferredSize` getter
  /// cannot call.
  double get _barHeight =>
      _padV * 2 +
      _slack +
      _textBlock * textScale.clamp(1.0, Responsive.maxTextScale);

  @override
  Size get preferredSize => Size.fromHeight(_barHeight + topInset);

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    final isManager = context.select<AuthBloc, bool>(
      (bloc) => bloc.state.user?.canEditVisits ?? false,
    );
    final eyebrow =
        isManager ? context.s.roleManagerTitle : context.s.roleEmployeeTitle;

    return Material(
      color: cs.surfaceContainerLowest,
      child: Container(
        height: _barHeight + topInset,
        padding: EdgeInsetsDirectional.fromSTEB(
          _padH,
          _padV + topInset,
          _padH,
          _padV,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: x.outlineVariant)),
        ),
        child: Row(
          children: [
            Container(
              width: CompSz.chip,
              height: CompSz.chip,
              decoration: BoxDecoration(
                gradient: x.avatarGradient,
                borderRadius: BorderRadius.circular(Radii.sm),
                boxShadow: x.elev1,
              ),
              alignment: Alignment.center,
              child: Image.asset(
                AppAssets.logoMark,
                width: IconSz.md,
                height: IconSz.md,
                color: AppColors.onMap,
              ),
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
                          height: _lineHeight,
                          fontWeight: FontWeight.w700,
                          letterSpacing: _eyebrowTracking,
                          color: cs.onSurfaceVariant)),
                  Text(title ?? context.s.appTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: FontSz.appBar,
                          height: _lineHeight,
                          fontWeight: FontWeight.w800,
                          letterSpacing: _titleTracking,
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
  /// Counts above this read as "99+": a wider badge would cover the bell.
  static const _maxShownCount = 99;

  /// How far the badge hangs past the chip's top-end corner.
  static const _badgeOverhang = -2.0;

  /// Tight enough that one digit makes a circle, wide enough for "99+".
  static const _badgePadding =
      EdgeInsets.symmetric(horizontal: 5, vertical: 1);

  int _count = 0;

  /// Bumped per request, so a slow answer that arrives after a newer one (a
  /// resume and a return from the feed, back to back) cannot overwrite it.
  int _generation = 0;

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
    final generation = ++_generation;
    try {
      final count = await sl<VisitsRepository>().myActivityCount();
      if (mounted && generation == _generation) setState(() => _count = count);
    } catch (e) {
      // Best-effort: a failed count must not break the app bar, and the feed
      // itself reports the failure when opened.
      appLog('[NotificationChip] unread count unavailable: $e');
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
            end: _badgeOverhang,
            top: _badgeOverhang,
            child: Container(
              padding: _badgePadding,
              constraints: BoxConstraints(
                minWidth: context.r(CompSz.medal),
                minHeight: context.r(CompSz.medal),
              ),
              decoration: BoxDecoration(
                color: cs.error,
                borderRadius: BorderRadius.circular(Radii.pill),
                border: Border.all(
                  color: cs.surfaceContainerLowest,
                  width: CompSz.outlineWidth,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _count > _maxShownCount
                    ? context.s.badgeOverflow(_maxShownCount)
                    : AppNumber.whole(_count),
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
