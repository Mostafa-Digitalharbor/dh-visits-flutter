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
import '../../visits/data/models/visit.dart';
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _DashboardGreeting(visits: visits),
              const SizedBox(height: 16),
              _KpiGrid(visits: visits),
              const SizedBox(height: 16),
              DashboardActiveMapCard(visits: visits),
              const SizedBox(height: 16),
              _LeaderboardCard(
                visits: visits,
                nameOf: (v) => v.customerName,
                title: context.s.dashboardTopCustomers,
                icon: Icons.business_rounded,
                color: (c) => c.colors.primary,
              ),
              const SizedBox(height: 16),
              _LeaderboardCard(
                visits: visits,
                nameOf: (v) => v.employeeName,
                // Finished work only — a draft is a commitment, not a delivery.
                where: (v) => v.isDone,
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
  final List<Visit> visits;
  const _DashboardGreeting({required this.visits});

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthBloc>().state.user;
    final today = DateTime.now();
    bool isToday(DateTime? d) =>
        d != null && d.year == today.year && d.month == today.month && d.day == today.day;
    final todays = visits.where((v) => isToday(v.effectiveDate)).toList();
    final done = todays.where((v) => v.isDone).length;
    final total = todays.isEmpty ? visits.length : todays.length;
    // Sum of completed visit durations → field time (hours, 1 decimal).
    final mins = visits
        .where((v) => v.visitDuration != null)
        .fold<int>(0, (s, v) => s + v.visitDuration!.inMinutes);
    final hours = (mins / 60).toStringAsFixed(mins % 60 == 0 ? 0 : 1);

    return GreetingHeader(
      name: user?.displayName ?? context.s.appTitle,
      roleLabel: context.s.roleManager,
      roleIcon: Symbols.shield_person,
      done: done,
      total: total,
      stats: [
        GreetingStat(
          icon: Symbols.event_available,
          value: '${todays.length}',
          label: context.s.dashboardKpiToday,
        ),
        GreetingStat(
          icon: Symbols.schedule,
          value: '$hours ${context.s.wfHoursShort}',
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
  final List<Visit> visits;
  const _KpiGrid({required this.visits});

  @override
  Widget build(BuildContext context) {
    final today = _today();
    final overdue = visits.where((v) => v.isOverdue).length;
    final pendingReview = visits
        .where((v) => v.isAwaitingApproval)
        .length;
    final todayCount = visits.where((v) {
      final d = v.effectiveDate;
      if (d == null) return false;
      return _sameDay(d, today);
    }).length;
    final activeNow = visits
        .where((v) => v.isInProgress)
        .length;
    // Tiles get taller as the OS font scale grows so the count + 2-line label
    // never clip; wider/narrower phones tweak it slightly via the width scale.
    final aspect = (1.45 / (context.textScale.clamp(1.0, 1.25) * context.widthScale))
        .clamp(1.05, 1.5);
    return GridView.count(
      crossAxisCount: 2,
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

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static bool _sameDay(DateTime a, DateTime today) {
    final aDay = DateTime(a.year, a.month, a.day);
    return aDay.isAtSameMomentAs(today);
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
                    style: AppType.number(34, color).copyWith(height: 1),
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
/// visits they counted, and the tint — so they are one widget with those three
/// as parameters.
class _LeaderboardCard extends StatelessWidget {
  final List<Visit> visits;

  /// The field to group by. Rows with no name are skipped.
  final String? Function(Visit) nameOf;

  /// Narrows the set before counting — the employee board counts finished work
  /// only, since a draft is a commitment, not a delivery.
  final bool Function(Visit)? where;

  final String title;
  final IconData icon;
  final Color Function(BuildContext) color;

  /// Icon on each row; defaults to the card's own [icon].
  final IconData? rowIcon;

  static const _maxRows = 5;

  const _LeaderboardCard({
    required this.visits,
    required this.nameOf,
    required this.title,
    required this.icon,
    required this.color,
    this.where,
    this.rowIcon,
  });

  @override
  Widget build(BuildContext context) {
    final source = where == null ? visits : visits.where(where!);
    final counts = <String, int>{};
    for (final v in source) {
      final name = nameOf(v);
      if (name == null || name.isEmpty) continue;
      counts[name] = (counts[name] ?? 0) + 1;
    }
    final shown = (counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(_maxRows)
        .toList();
    // Guard the divisor, not just the display: an empty board would otherwise
    // divide by zero when computing each row's bar fraction.
    final maxCount = shown.isEmpty ? 1 : shown.first.value;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(icon: icon, label: title),
          const SizedBox(height: 10),
          if (shown.isEmpty)
            InlineEmptyRow(text: context.s.dashboardNoData)
          else
            for (final e in shown)
              _LeaderboardRow(
                name: e.key,
                count: e.value,
                fraction: e.value / maxCount,
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
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.badge),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: fraction.clamp(0, 1),
                    backgroundColor: colors.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$count',
            style: context.text.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}


class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: const [
          SkeletonCard(height: 200),
          SizedBox(height: 16),
          SkeletonCard(height: 280),
          SizedBox(height: 16),
          SkeletonCard(height: 220),
          SizedBox(height: 16),
          SkeletonCard(height: 220),
        ],
      ),
    );
  }
}
