import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../visits/bloc/visits_list_bloc.dart';
import '../../visits/data/models/visit.dart';

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
        final visits = state.items;
        return RefreshIndicator(
          onRefresh: () async {
            final isAdmin =
                context.read<AuthBloc>().state.user?.canEditVisits ?? false;
            context
                .read<VisitsListBloc>()
                .add(VisitsListLoadRequested(includeDrafts: isAdmin));
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _DashboardGreeting(visits: visits),
              const SizedBox(height: 16),
              _KpiGrid(visits: visits),
              const SizedBox(height: 16),
              _ActiveEmployeesCard(visits: visits),
              const SizedBox(height: 16),
              _TopCustomersCard(visits: visits),
              const SizedBox(height: 16),
              _TopEmployeesCard(visits: visits),
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
    final done = todays.where((v) => v.state == VisitStateType.checkedOut).length;
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
          value: '$hours س',
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
        .where((v) => v.lifecycleState == VisitLifecycleState.underReview)
        .length;
    final todayCount = visits.where((v) {
      final d = v.effectiveDate;
      if (d == null) return false;
      return _sameDay(d, today);
    }).length;
    final activeNow = visits
        .where((v) => v.state == VisitStateType.checkedIn)
        .length;
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.45,
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
                      .add(const VisitsListFilterChanged(VisitsFilter.all));
                  context.read<VisitsListBloc>().add(
                        VisitsListTimingFilterChanged(VisitTimingFilter.overdue),
                      );
                  context.go('/');
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
                  context.push('/review');
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
                .add(const VisitsListFilterChanged(VisitsFilter.today));
            context.go('/');
          },
        ),
        _KpiTile(
          label: context.s.dashboardKpiActive,
          value: activeNow,
          color: Colors.green.shade600,
          icon: Icons.bolt_rounded,
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
              CountUpText(
                '$value',
                style: AppType.number(34, color).copyWith(height: 1),
              ),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppType.bodyMd.copyWith(
                  color: context.colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Static (non-interactive) map preview showing every currently
/// checked-in employee at their last recorded coordinates. Tapping a
/// pin opens the associated visit detail — the admin can drill from
/// "who's where right now?" to "what are they doing?".
class _ActiveEmployeesCard extends StatelessWidget {
  final List<Visit> visits;
  const _ActiveEmployeesCard({required this.visits});

  @override
  Widget build(BuildContext context) {
    final active = visits
        .where((v) =>
            v.state == VisitStateType.checkedIn && v.hasCheckInLocation)
        .toList();
    if (active.isEmpty) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              icon: Icons.location_on_rounded,
              label: context.s.dashboardActiveOnMapTitle,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.person_off_outlined,
                      size: 20, color: context.colors.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.s.dashboardActiveEmpty,
                      style: TextStyle(
                          color: context.colors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final points = active
        .map((v) => LatLng(v.checkInLat!, v.checkInLng!))
        .toList();
    final bounds = LatLngBounds.fromPoints(points);
    // CameraFit.bounds divides by the bounds' span to derive a zoom; a single
    // active visit (or several at the exact same spot) gives a zero-span box,
    // producing an Infinity/NaN zoom that crashes the tile layer. Only fit when
    // the points actually span an area, otherwise centre on them at a fixed zoom.
    final latSpan = (bounds.north - bounds.south).abs();
    final lngSpan = (bounds.east - bounds.west).abs();
    final canFitBounds = latSpan > 1e-4 && lngSpan > 1e-4;
    final mapCenter = LatLng(
      (bounds.north + bounds.south) / 2,
      (bounds.east + bounds.west) / 2,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: _SectionTitle(
                    icon: Icons.location_on_rounded,
                    label: context.s.dashboardActiveOnMapTitle,
                  ),
                ),
                _CountBadge(value: active.length),
              ],
            ),
          ),
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(14)),
            child: SizedBox(
              height: 220,
              child: AbsorbPointer(
                // Block gesture forwarding into the map so the admin can
                // scroll past it. The buttons inside are still tappable
                // because they sit above this in the stack.
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: mapCenter,
                    initialZoom: 15,
                    initialCameraFit: canFitBounds
                        ? CameraFit.bounds(
                            bounds: bounds,
                            padding: const EdgeInsets.all(40),
                          )
                        : null,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                    backgroundColor: isDark
                        ? const Color(0xFF1A1A1A)
                        : const Color(0xFFE5E5E5),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.digitalharbor.location_gps',
                      maxNativeZoom: 19,
                      maxZoom: 22,
                    ),
                    MarkerLayer(
                      markers: [
                        for (final v in active)
                          Marker(
                            point: LatLng(v.checkInLat!, v.checkInLng!),
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            child: _ActivePin(name: v.employeeName ?? '?'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: Column(
              children: [
                for (final v in active.take(3))
                  ListTile(
                    visualDensity: VisualDensity.compact,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.green.shade100,
                      child: Text(
                        (v.employeeName ?? '?').isNotEmpty
                            ? v.employeeName![0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Text(
                      v.employeeName ?? '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      v.customerName ?? '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall,
                    ),
                    trailing: Icon(Icons.chevron_right,
                        color: context.colors.onSurfaceVariant),
                    onTap: () => context.push('/visits/${v.id}', extra: v),
                  ),
                if (active.length > 3)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        context.s.dashboardActiveMore(active.length - 3),
                        style: context.text.labelSmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivePin extends StatelessWidget {
  final String name;
  const _ActivePin({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.green.shade500, Colors.green.shade800],
        ),
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _TopCustomersCard extends StatelessWidget {
  final List<Visit> visits;
  const _TopCustomersCard({required this.visits});

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final v in visits) {
      final name = v.customerName;
      if (name == null || name.isEmpty) continue;
      counts[name] = (counts[name] ?? 0) + 1;
    }
    final top = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final shown = top.take(5).toList();
    final maxCount = shown.isEmpty ? 1 : shown.first.value;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.business_rounded,
            label: context.s.dashboardTopCustomers,
          ),
          const SizedBox(height: 10),
          if (shown.isEmpty)
            _EmptyRow(text: context.s.dashboardNoData)
          else
            for (final e in shown)
              _LeaderboardRow(
                name: e.key,
                count: e.value,
                fraction: e.value / maxCount,
                color: context.colors.primary,
                icon: Icons.business_rounded,
              ),
        ],
      ),
    );
  }
}

class _TopEmployeesCard extends StatelessWidget {
  final List<Visit> visits;
  const _TopEmployeesCard({required this.visits});

  @override
  Widget build(BuildContext context) {
    // Count only finished work for the employee leaderboard — drafts
    // and pending visits shouldn't reward an employee yet, those are
    // commitments not deliveries.
    final completedOnly =
        visits.where((v) => v.state == VisitStateType.checkedOut);
    final counts = <String, int>{};
    for (final v in completedOnly) {
      final name = v.employeeName;
      if (name == null || name.isEmpty) continue;
      counts[name] = (counts[name] ?? 0) + 1;
    }
    final top = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final shown = top.take(5).toList();
    final maxCount = shown.isEmpty ? 1 : shown.first.value;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.emoji_events_rounded,
            label: context.s.dashboardTopEmployees,
          ),
          const SizedBox(height: 10),
          if (shown.isEmpty)
            _EmptyRow(text: context.s.dashboardNoData)
          else
            for (final e in shown)
              _LeaderboardRow(
                name: e.key,
                count: e.value,
                fraction: e.value / maxCount,
                color: context.colors.tertiary,
                icon: Icons.person_rounded,
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
                  borderRadius: BorderRadius.circular(6),
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

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.colors.primary),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int value;
  const _CountBadge({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.shade600.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Colors.green.shade600.withValues(alpha: 0.30)),
      ),
      child: Text(
        '$value',
        style: TextStyle(
          color: Colors.green.shade700,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  final String text;
  const _EmptyRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(Icons.inbox_outlined,
              color: context.colors.onSurfaceVariant, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: context.colors.onSurfaceVariant),
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
