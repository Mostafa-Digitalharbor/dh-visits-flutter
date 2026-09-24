import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/utils/app_number.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../visits/bloc/visits_list_bloc.dart';
import '../../visits/domain/visit_metrics.dart';
import 'dashboard_active_map_card.dart';
import 'visits_list_feedback.dart';

/// Admin-only landing screen. Aggregates the existing `VisitsListBloc`
/// items into a quick-glance overview: actionable counts (overdue +
/// pending review), today's pipeline, top customers / employees by
/// volume, and a mini-map of who's checked in right now.
///
/// The page is intentionally read-only — every card is a shortcut into
/// the existing Visits/Customers screens, never an alternative editing
/// surface. That keeps Odoo as the single source of truth and avoids
/// duplicate write paths.
class DashboardPage extends StatelessWidget {
  /// Opens the Visits tab narrowed to [VisitsListFocus]. Supplied by the
  /// manager shell, which owns the tabs; without it the count tiles are not
  /// tappable (the review tile still is — it is a route of its own).
  final ValueChanged<VisitsListFocus>? onOpenVisits;

  const DashboardPage({super.key, this.onOpenVisits});

  @override
  Widget build(BuildContext context) {
    return VisitsRefreshFailureListener(
      child: BlocBuilder<VisitsListBloc, VisitsListState>(
        builder: (context, state) {
          // `initial` too: the first frame comes before the shell's load event
          // is handled, and would otherwise flash a row of zeros.
          if (state.items.isEmpty &&
              (state.status == VisitsListStatus.loading ||
                  state.status == VisitsListStatus.initial)) {
            return const _DashboardSkeleton();
          }
          // A failed fetch must not render as "Overdue 0 · Pending 0 · Today
          // 0": the manager would read that as an authoritative "nothing
          // outstanding" and close the app. Only fall back to the error view
          // when there is no data at all — a failed refresh over a populated
          // dashboard keeps the last good numbers and says so in a snackbar
          // ([VisitsRefreshFailureListener]).
          if (state.status == VisitsListStatus.failure && state.items.isEmpty) {
            return ErrorView(
              message: state.error?.localize(context) ?? context.s.errUnknown,
              onRetry: () => reloadTeamVisits(context),
            );
          }
          final visits = state.items;
          // One sweep for the whole screen. Every tile below reads a field
          // off this instead of running its own pass on each rebuild — see
          // [DashboardSummary].
          final summary = DashboardSummary.from(visits);
          return AppRefreshIndicator(
            onRefresh: () => reloadTeamVisits(context),
            child: ListView(
              padding: _pagePadding(context),
              children: [
                _DashboardGreeting(summary: summary),
                context.gapH(Insets.cardGap),
                _KpiGrid(summary: summary, onOpenVisits: onOpenVisits),
                context.gapH(Insets.cardGap),
                // The map is the only child that paints continuously (tile
                // fades, marker layers). Without a boundary its raster is
                // discarded whenever a sibling KPI number animates.
                RepaintBoundary(child: DashboardActiveMapCard(visits: visits)),
                context.gapH(Insets.cardGap),
                _LeaderboardCard(
                  entries: summary.topCustomers,
                  title: context.s.dashboardTopCustomers,
                  icon: Icons.business_rounded,
                  color: context.colors.primary,
                ),
                context.gapH(Insets.cardGap),
                _LeaderboardCard(
                  entries: summary.topEmployees,
                  title: context.s.dashboardTopEmployees,
                  icon: Icons.emoji_events_rounded,
                  rowIcon: Icons.person_rounded,
                  color: context.colors.tertiary,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Brand-gradient greeting header at the top of the manager dashboard.
class _DashboardGreeting extends StatelessWidget {
  final DashboardSummary summary;
  const _DashboardGreeting({required this.summary});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    // `select`, not `read`: the name follows a profile refresh.
    final name = context.select((AuthBloc b) => b.state.user?.displayName);
    return GreetingHeader(
      name: name ?? s.appTitle,
      roleLabel: s.roleManager,
      roleIcon: Symbols.shield_person,
      done: summary.todayDone,
      total: summary.todayTotal,
      stats: [
        GreetingStat(
          icon: Symbols.event_available,
          value: AppNumber.whole(summary.today),
          label: s.dashboardKpiToday,
        ),
        GreetingStat(
          icon: Symbols.schedule,
          value: s.dashboardFieldHoursValue(AppNumber.decimal(
              summary.fieldMinutes / Duration.minutesPerHour)),
          label: s.dashboardFieldTime,
        ),
      ],
    );
  }
}

/// Grid of headline counts. Each count tile opens the Visits tab narrowed to
/// what it counts — "Overdue: 3" → tap → exactly those three — so the manager
/// never has to find the matching filter.
class _KpiGrid extends StatelessWidget {
  final DashboardSummary summary;
  final ValueChanged<VisitsListFocus>? onOpenVisits;
  const _KpiGrid({required this.summary, required this.onOpenVisits});

  /// A tile's width : height at the design scale.
  static const double _designAspect = 1.45;

  /// How far the aspect may bend: taller for large fonts (the count and a
  /// two-line label must not clip), never so tall a tile looks empty.
  static const double _minAspect = 1.05;
  static const double _maxAspect = 1.5;

  static const int _phoneColumns = 2;
  static const int _tabletColumns = 4;

  /// A tap that opens [focus] — only when the shell can switch tabs and there
  /// is something to show.
  VoidCallback? _opener(VisitsListFocus focus, {required bool hasItems}) {
    final open = onOpenVisits;
    if (open == null || !hasItems) return null;
    return () {
      HapticFeedback.selectionClick();
      open(focus);
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    // Four across on a tablet, two on a phone.
    //
    // Not cosmetic: `childAspectRatio` sets height as a fraction of the column
    // width, so two columns on a ~1070dp tablet gave each tile a ~360dp
    // height — a mostly empty card with the count stranded in the middle.
    final columns = context.isTablet ? _tabletColumns : _phoneColumns;
    // Tiles get taller as the OS font scale grows so the count + 2-line label
    // never clip; wider/narrower phones tweak it slightly via the width scale.
    final textGrowth = context.textScale.clamp(1.0, Responsive.maxTextScale);
    final aspect = (_designAspect / (textGrowth * context.widthScale))
        .clamp(_minAspect, _maxAspect);
    final spacing = context.r(Insets.x3);
    return GridView.count(
      crossAxisCount: columns,
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: aspect,
      children: [
        _KpiTile(
          label: s.dashboardKpiOverdue,
          value: summary.overdue,
          color: context.colors.error,
          icon: Icons.warning_amber_rounded,
          onTap: _opener(VisitsListFocus.overdue, hasItems: summary.overdue > 0),
        ),
        _KpiTile(
          label: s.dashboardKpiPending,
          value: summary.pendingReview,
          color: context.x.warning,
          icon: Symbols.pending,
          onTap: summary.pendingReview > 0
              ? () {
                  HapticFeedback.selectionClick();
                  context.push(AppRoutes.review);
                }
              : null,
        ),
        _KpiTile(
          label: s.dashboardKpiToday,
          value: summary.today,
          color: context.colors.primary,
          icon: Icons.today_rounded,
          // Open even at zero: the list then says there is nothing today,
          // which is the answer the manager tapped for.
          onTap: _opener(VisitsListFocus.today, hasItems: true),
        ),
        _KpiTile(
          label: s.dashboardKpiActive,
          value: summary.activeNow,
          color: context.x.success,
          icon: Icons.bolt_rounded,
          onTap: _opener(VisitsListFocus.inProgress,
              hasItems: summary.activeNow > 0),
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;
  const _KpiTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(Radii.lg);
    final glyph = context.r(IconSz.tile);
    return Material(
      borderRadius: radius,
      color: color.withValues(alpha: Alphas.tint),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: context.padAll(Insets.x4),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: color.withValues(alpha: Alphas.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Symbols chevrons mirror themselves in RTL; picking the
                  // left one for Arabic flipped it back the wrong way.
                  Icon(
                    Symbols.chevron_right,
                    size: glyph,
                    color: onTap != null
                        ? color.withValues(alpha: Alphas.subdued)
                        : Colors.transparent,
                  ),
                  Icon(icon, fill: 1, size: glyph, color: color),
                ],
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: CountUpText(
                    '$value',
                    style: AppType.number(FontSz.kpi, color).copyWith(height: 1),
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.bodyMd.copyWith(
                    color: context.colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Top N by visit count" card. The customers and employees leaderboards were
/// two classes whose bodies differed only in which field they grouped by, which
/// visits they counted, and the tint — so they are one widget, and the counting
/// itself happens once in [DashboardSummary] rather than per card.
class _LeaderboardCard extends StatelessWidget {
  /// Already ranked and truncated — see [DashboardSummary].
  final List<LeaderboardEntry> entries;

  final String title;
  final IconData icon;
  final Color color;

  /// Icon on each row; defaults to the card's own [icon].
  final IconData? rowIcon;

  const _LeaderboardCard({
    required this.entries,
    required this.title,
    required this.icon,
    required this.color,
    this.rowIcon,
  });

  @override
  Widget build(BuildContext context) {
    // Guard the divisor, not just the display: an empty board would otherwise
    // divide by zero when computing each row's bar fraction.
    final maxCount = entries.isEmpty ? 1 : entries.first.count;
    final disc = context.r(CompSz.infoDot);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(icon: icon, label: title),
          context.gapH(Insets.x2h),
          if (entries.isEmpty)
            InlineEmptyRow(text: context.s.dashboardNoData)
          else
            for (final e in entries)
              LeaderboardRow(
                // A tinted icon disc rather than an initial: these boards rank
                // customers and employees alike, and a company has no
                // meaningful initial.
                leading: IconBadge(
                  icon: rowIcon ?? icon,
                  color: color,
                  size: disc,
                  iconSize: context.r(IconSz.inline),
                  radius: disc / 2,
                  tintAlpha: Alphas.tintStrong,
                ),
                name: e.name,
                figure: AppNumber.whole(e.count),
                value: e.count / maxCount,
                color: color,
              ),
        ],
      ),
    );
  }
}

/// Shared by the page and its skeleton so the two cannot drift. The extra
/// bottom inset clears the shell's nav bar.
EdgeInsets _pagePadding(BuildContext context) => EdgeInsets.fromLTRB(
      context.r(Insets.screen),
      context.r(Insets.screen),
      context.r(Insets.screen),
      context.rh(Insets.x6),
    );

// Placeholder heights for [_DashboardSkeleton] — measured from the blocks they
// stand in for.

/// Gradient greeting card: avatar, two text lines and the progress strip.
const double _greetingHeight = 200.0;

/// The 2×2 KPI grid.
const double _kpiGridHeight = 280.0;

/// The live-map card: its header, the [CompSz.mapCard] map and the rows under
/// it.
const double _mapCardHeight = 380.0;

/// A leaderboard card: header plus five rows.
const double _boardHeight = 220.0;

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    // Greeting, KPI grid, map card, then the two leaderboards — the real
    // page's rhythm, so nothing shifts when the data lands. Heights follow
    // the text scale the way the real cards grow with it.
    final gap = context.gapH(Insets.cardGap);
    final board = SkeletonCard(height: context.fixedH(_boardHeight));
    return AppShimmer(
      child: ListView(
        padding: _pagePadding(context),
        children: [
          SkeletonCard(height: context.fixedH(_greetingHeight)),
          gap,
          SkeletonCard(height: context.fixedH(_kpiGridHeight)),
          gap,
          SkeletonCard(height: context.fixedH(_mapCardHeight)),
          gap,
          board,
          gap,
          board,
        ],
      ),
    );
  }
}
