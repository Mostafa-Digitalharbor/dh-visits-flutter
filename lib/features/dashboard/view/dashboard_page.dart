import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../visits/bloc/visits_list_bloc.dart';
import '../../visits/domain/visit_metrics.dart';
import 'dashboard_active_map_card.dart';

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
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VisitsListBloc, VisitsListState>(
      builder: (context, state) {
        if (state.status == VisitsListStatus.loading && state.items.isEmpty) {
          return const _DashboardSkeleton();
        }
        // A failed fetch must not render as "Overdue 0 · Pending 0 · Today 0":
        // the manager would read that as an authoritative "nothing outstanding"
        // and close the app. Only fall back to the error view when we have no
        // data at all — a failed refresh over a populated dashboard keeps the
        // last good numbers and reports itself through the refresh indicator.
        if (state.status == VisitsListStatus.failure && state.items.isEmpty) {
          return ErrorView(
            message: state.error?.localize(context) ?? context.s.errUnknown,
            onRetry: () => context
                .read<VisitsListBloc>()
                .add(const VisitsListLoadRequested()),
          );
        }
        final visits = state.items;
        // One sweep for the whole screen. Every tile below reads a field off
        // this instead of running its own `visits.where(...)` pass on each
        // rebuild — see [DashboardSummary].
        final summary = DashboardSummary.from(visits);
        return AppRefreshIndicator(
          onRefresh: () async {
            final isAdmin =
                context.read<AuthBloc>().state.user?.canEditVisits ?? false;
            context.read<VisitsListBloc>().add(VisitsListLoadRequested(
                  scope:
                      isAdmin ? VisitListScope.team : VisitListScope.mine,
                ));
          },
          child: ListView(
            padding: _pagePadding(context),
            children: [
              _DashboardGreeting(summary: summary),
              context.gapH(Insets.cardGap),
              _KpiGrid(summary: summary),
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
                color: (c) => c.colors.primary,
              ),
              context.gapH(Insets.cardGap),
              _LeaderboardCard(
                entries: summary.topEmployees,
                title: context.s.dashboardTopEmployees,
                icon: Icons.emoji_events_rounded,
                rowIcon: Icons.person_rounded,
                color: (c) => c.colors.tertiary,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Brand-gradient greeting header at the top of the manager dashboard.
class _DashboardGreeting extends StatelessWidget {
  final DashboardSummary summary;
  const _DashboardGreeting({required this.summary});

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthBloc>().state.user;
    return GreetingHeader(
      name: user?.displayName ?? context.s.appTitle,
      roleLabel: context.s.roleManager,
      roleIcon: Symbols.shield_person,
      done: summary.todayDone,
      total: summary.todayTotal,
      stats: [
        GreetingStat(
          icon: Symbols.event_available,
          value: '${summary.today}',
          label: context.s.dashboardKpiToday,
        ),
        GreetingStat(
          icon: Symbols.schedule,
          value: '${summary.fieldHoursLabel} ${context.s.wfHoursShort}',
          label: context.s.dashboardFieldTime,
        ),
      ],
    );
  }
}

/// 2x2 grid of headline numbers. Each tile is tappable and routes the
/// admin straight into the Visits list with the matching filter
/// pre-applied — so "Overdue: 3" → tap → Visits screen filtered to
/// past-due. Removes the friction of explaining filters to the admin.
class _KpiGrid extends StatelessWidget {
  final DashboardSummary summary;
  const _KpiGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    final overdue = summary.overdue;
    final pendingReview = summary.pendingReview;
    final todayCount = summary.today;
    final activeNow = summary.activeNow;
    // Four across on a tablet, two on a phone.
    //
    // Not cosmetic: `childAspectRatio` sets height as a fraction of the column
    // width, so two columns on a ~1070dp tablet gave each tile a ~520dp width
    // and, at this ratio, a ~360dp height — a mostly empty card with the count
    // stranded in the middle of it. Nothing overflowed, which is why only
    // looking at the device caught this. Splitting into four keeps each tile
    // near its designed phone proportions and uses the extra width for what it
    // is worth: seeing all four numbers in one glance.
    final columns = context.isTablet ? 4 : 2;
    // Tiles get taller as the OS font scale grows so the count + 2-line label
    // never clip; wider/narrower phones tweak it slightly via the width scale.
    final aspect = (1.45 / (context.textScale.clamp(1.0, 1.25) * context.widthScale))
        .clamp(1.05, 1.5);
    return GridView.count(
      crossAxisCount: columns,
      mainAxisSpacing: context.r(12),
      crossAxisSpacing: context.r(12),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: aspect,
      children: [
        _KpiTile(
          label: context.s.dashboardKpiOverdue,
          value: overdue,
          color: Colors.red.shade600,
          icon: Icons.warning_amber_rounded,
          onTap: overdue > 0
              ? () {
                  HapticFeedback.selectionClick();
                  context
                      .read<VisitsListBloc>()
                      .add(const VisitsListScopeChanged(VisitListScope.team));
                  context.go(AppRoutes.splash);
                }
              : null,
        ),
        _KpiTile(
          label: context.s.dashboardKpiPending,
          value: pendingReview,
          color: context.x.warning,
          icon: Symbols.pending,
          onTap: pendingReview > 0
              ? () {
                  HapticFeedback.selectionClick();
                  context.push(AppRoutes.review);
                }
              : null,
        ),
        _KpiTile(
          label: context.s.dashboardKpiToday,
          value: todayCount,
          color: context.colors.primary,
          icon: Icons.today_rounded,
          onTap: () {
            HapticFeedback.selectionClick();
            context
                .read<VisitsListBloc>()
                .add(const VisitsListScopeChanged(VisitListScope.team));
            context.go(AppRoutes.splash);
          },
        ),
        _KpiTile(
          label: context.s.dashboardKpiActive,
          value: activeNow,
          color: Colors.green.shade600,
          icon: Icons.bolt_rounded,
          onTap: activeNow > 0
              ? () {
                  HapticFeedback.selectionClick();
                  context
                      .read<VisitsListBloc>()
                      .add(const VisitsListScopeChanged(VisitListScope.team));
                  context.go(AppRoutes.splash);
                }
              : null,
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
    return Material(
      borderRadius: BorderRadius.circular(Radii.lg),
      color: color.withValues(alpha: 0.12),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: color.withValues(alpha: 0.30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    context.isRtl ? Symbols.chevron_left : Symbols.chevron_right,
                    size: 22,
                    color: onTap != null ? color.withValues(alpha: 0.7) : Colors.transparent,
                  ),
                  Icon(icon, fill: 1, size: 22, color: color),
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
/// itself now happens once in [DashboardSummary] rather than per card.
class _LeaderboardCard extends StatelessWidget {
  /// Already ranked and truncated — see [DashboardSummary].
  final List<LeaderboardEntry> entries;

  final String title;
  final IconData icon;
  final Color Function(BuildContext) color;

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
              _LeaderboardRow(
                name: e.name,
                count: e.count,
                fraction: e.count / maxCount,
                color: color(context),
                icon: rowIcon ?? icon,
              ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final String name;
  final int count;
  final double fraction;
  final Color color;
  final IconData icon;
  const _LeaderboardRow({
    required this.name,
    required this.count,
    required this.fraction,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final disc = context.r(CompSz.infoDot);
    return LeaderboardRow(
      // A tinted icon disc rather than an initial: these boards rank customers
      // and employees alike, and a company has no meaningful initial.
      leading: IconBadge(
        icon: icon,
        color: color,
        size: disc,
        iconSize: context.r(IconSz.inline),
        radius: disc / 2,
        tintAlpha: Alphas.tintStrong,
      ),
      name: name,
      figure: '$count',
      value: fraction,
      color: color,
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

/// A leaderboard card: header plus five rows.
const double _boardHeight = 220.0;

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    // Greeting, KPI grid, map card, then the two leaderboards — the real
    // page's rhythm, so nothing shifts when the data lands.
    final gap = context.gapH(Insets.cardGap);
    final board = SkeletonCard(height: context.r(_boardHeight));
    return AppShimmer(
      child: ListView(
        padding: _pagePadding(context),
        children: [
          SkeletonCard(height: context.r(_greetingHeight)),
          gap,
          SkeletonCard(height: context.r(_kpiGridHeight)),
          gap,
          board,
          gap,
          board,
        ],
      ),
    );
  }
}
