import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/visits_list_bloc.dart';
import '../data/models/visit.dart';

/// Primary visits screen. Used by both User and Manager roles — the backend
/// record rule already restricts non-managers to their own visits.
class VisitsListPage extends StatefulWidget {
  const VisitsListPage({super.key});

  @override
  State<VisitsListPage> createState() => _VisitsListPageState();
}

class _VisitsListPageState extends State<VisitsListPage> {
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    // Trigger initial load on first mount. The bloc preserves filter
    // selection across rebuilds, so this is a no-op refresh on tab switch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _dispatchLoad();
      _searchCtrl.text =
          context.read<VisitsListBloc>().state.searchQuery;
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _dispatchLoad() {
    final isManager =
        context.read<AuthBloc>().state.user?.canEditVisits ?? false;
    context
        .read<VisitsListBloc>()
        .add(VisitsListLoadRequested(includeDrafts: isManager));
  }

  Future<void> _refresh() async => _dispatchLoad();

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      context
          .read<VisitsListBloc>()
          .add(VisitsListSearchChanged(value.trim()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _MyDayHeader(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) {
              _onSearchChanged(v);
              setState(() {});
            },
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: context.s.visitsSearchHint,
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _onSearchChanged('');
                        setState(() {});
                      },
                    ),
              isDense: true,
            ),
          ),
        ),
        const _FilterChips(),
        const _AdminFilterChips(),
        Expanded(
          child: BlocBuilder<VisitsListBloc, VisitsListState>(
            builder: (context, state) {
              final isLoading =
                  state.status == VisitsListStatus.loading;
              if (state.status == VisitsListStatus.failure &&
                  state.items.isEmpty) {
                return ErrorView(
                  message: state.error?.localize(context) ??
                      context.s.errUnknown,
                  onRetry: _refresh,
                );
              }
              // Apply client-side Today/All filter first. We filter by
              // `effectiveDate` — finished visits use their check-out
              // time, in-progress ones use check-in, drafts use the
              // scheduled visit_date. That way a visit scheduled for
              // today but completed yesterday drops out of "Today"
              // (it's done, no need to surface it again today).
              final now = DateTime.now();
              final todayStart = DateTime(now.year, now.month, now.day);
              final todayEnd =
                  todayStart.add(const Duration(days: 1));
              bool isToday(DateTime d) =>
                  !d.isBefore(todayStart) && d.isBefore(todayEnd);
              final dateFiltered = state.filter == VisitsFilter.all
                  ? state.items
                  : state.items.where((v) {
                      final d = v.effectiveDate;
                      // No date info at all — keep visible so the user
                      // can act on it instead of losing it silently.
                      if (d == null) return true;
                      return isToday(d);
                    }).toList();

              // Admin-only secondary slicers (status + timing). They're
              // baked into bloc state so we can apply them here without
              // worrying about who's logged in — the chips are only
              // rendered for managers, and switching back to "Today"
              // resets them to `all`.
              final statusFiltered = switch (state.statusFilter) {
                VisitStatusFilter.all => dateFiltered,
                VisitStatusFilter.completed => dateFiltered
                    .where((v) => v.state == VisitStateType.checkedOut)
                    .toList(),
                VisitStatusFilter.pendingReview => dateFiltered
                    .where((v) =>
                        v.lifecycleState == VisitLifecycleState.underReview)
                    .toList(),
                VisitStatusFilter.incomplete => dateFiltered
                    .where((v) => v.state != VisitStateType.checkedOut)
                    .toList(),
              };
              final timingFiltered = switch (state.timingFilter) {
                VisitTimingFilter.all => statusFiltered,
                VisitTimingFilter.onTime => statusFiltered
                    .where((v) => v.executionDaysDelta == 0)
                    .toList(),
                VisitTimingFilter.early => statusFiltered
                    .where((v) =>
                        v.executionDaysDelta != null &&
                        v.executionDaysDelta! < 0)
                    .toList(),
                // Past due bucket covers both pending-past-deadline and
                // completed-late, since both signal slipped scheduling.
                VisitTimingFilter.overdue => statusFiltered
                    .where((v) =>
                        v.isOverdue ||
                        (v.executionDaysDelta != null &&
                            v.executionDaysDelta! > 0))
                    .toList(),
              };

              // Then apply the search box on top.
              final q = state.searchQuery.toLowerCase();
              final searched = q.isEmpty
                  ? timingFiltered
                  : timingFiltered
                      .where((v) =>
                          (v.customerName ?? '').toLowerCase().contains(q))
                      .toList();

              // Crossfade between skeleton (loading) and content. Using an
              // AnimatedSwitcher keyed on the body type so the in/out
              // animations run instead of an abrupt swap.
              Widget body;
              if (isLoading) {
                body = const _VisitsSkeleton(key: ValueKey('skeleton'));
              } else if (searched.isEmpty) {
                final msg = q.isNotEmpty
                    ? context.s.pickerNoResults
                    : state.filter == VisitsFilter.today
                        ? context.s.visitsTodayEmpty
                        : context.s.visitsHistoryEmpty;
                body = ScaleFadeIn(
                  key: const ValueKey('empty'),
                  child: ListView(
                    children: [
                      const SizedBox(height: 80),
                      EmptyView(
                        icon: Icons.event_busy_outlined,
                        message: msg,
                      ),
                    ],
                  ),
                );
              } else {
                body = _GroupedList(
                  key: const ValueKey('list'),
                  visits: searched,
                  showGroups: state.filter == VisitsFilter.all,
                  searchQuery: state.searchQuery,
                );
              }

              return AppRefreshIndicator(
                onRefresh: _refresh,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: body,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Employee-only brand greeting/day header (design screen 10 · My Visits).
/// Hidden for managers — their visits tab is "team visits" with no greeting.
class _MyDayHeader extends StatelessWidget {
  const _MyDayHeader();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthBloc>().state.user;
    if (user == null || user.canEditVisits) return const SizedBox.shrink();
    return BlocBuilder<VisitsListBloc, VisitsListState>(
      builder: (context, state) {
        final today = DateTime.now();
        bool isToday(DateTime? d) =>
            d != null && d.year == today.year && d.month == today.month && d.day == today.day;
        final todays = state.items.where((v) => isToday(v.effectiveDate)).toList();
        final done = todays.where((v) => v.state == VisitStateType.checkedOut).length;
        final total = todays.isEmpty ? state.items.length : todays.length;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: GreetingHeader(
            name: user.displayName,
            roleLabel: context.s.roleUser,
            roleIcon: Symbols.badge,
            done: done,
            total: total,
          ),
        );
      },
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: BlocBuilder<VisitsListBloc, VisitsListState>(
        buildWhen: (p, c) => p.filter != c.filter,
        builder: (context, state) {
          return Row(
            children: [
              _FilterChip(
                label: context.s.visitsFilterToday,
                icon: Icons.today_rounded,
                selected: state.filter == VisitsFilter.today,
                onTap: () {
                  HapticFeedback.selectionClick();
                  context
                      .read<VisitsListBloc>()
                      .add(const VisitsListFilterChanged(
                          VisitsFilter.today));
                },
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: context.s.visitsFilterAll,
                icon: Icons.all_inclusive_rounded,
                selected: state.filter == VisitsFilter.all,
                onTap: () {
                  HapticFeedback.selectionClick();
                  context
                      .read<VisitsListBloc>()
                      .add(const VisitsListFilterChanged(
                          VisitsFilter.all));
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Admin-only secondary filters under the Today/All chips. Compacted
/// into two side-by-side dropdowns (Status + Timing) so they take a
/// single line instead of dominating the screen.
///
/// Renders nothing for non-admin users, and also nothing when the date
/// filter is "Today" (the slicers are noise there since today's visits
/// are already in flight).
class _AdminFilterChips extends StatelessWidget {
  const _AdminFilterChips();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthBloc>().state.user;
    final isAdmin = user?.canEditVisits ?? false;
    if (!isAdmin) return const SizedBox.shrink();
    return BlocBuilder<VisitsListBloc, VisitsListState>(
      buildWhen: (p, c) =>
          p.filter != c.filter ||
          p.statusFilter != c.statusFilter ||
          p.timingFilter != c.timingFilter,
      builder: (context, state) {
        if (state.filter != VisitsFilter.all) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: _FilterDropdown<VisitStatusFilter>(
                  label: context.s.filterStatusLabel,
                  value: state.statusFilter,
                  isDefault: state.statusFilter == VisitStatusFilter.all,
                  options: [
                    _DropdownOption(
                      value: VisitStatusFilter.all,
                      label: context.s.filterStatusAll,
                      icon: Icons.all_inclusive_rounded,
                    ),
                    _DropdownOption(
                      value: VisitStatusFilter.pendingReview,
                      label: context.s.filterStatusPendingReview,
                      icon: Icons.rate_review_rounded,
                    ),
                    _DropdownOption(
                      value: VisitStatusFilter.completed,
                      label: context.s.filterStatusCompleted,
                      icon: Icons.check_circle_rounded,
                    ),
                    _DropdownOption(
                      value: VisitStatusFilter.incomplete,
                      label: context.s.filterStatusIncomplete,
                      icon: Icons.schedule_rounded,
                    ),
                  ],
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    context
                        .read<VisitsListBloc>()
                        .add(VisitsListStatusFilterChanged(v));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterDropdown<VisitTimingFilter>(
                  label: context.s.filterTimingLabel,
                  value: state.timingFilter,
                  isDefault: state.timingFilter == VisitTimingFilter.all,
                  options: [
                    _DropdownOption(
                      value: VisitTimingFilter.all,
                      label: context.s.filterTimingAll,
                      icon: Icons.all_inclusive_rounded,
                    ),
                    _DropdownOption(
                      value: VisitTimingFilter.onTime,
                      label: context.s.filterTimingOnTime,
                      icon: Icons.check_rounded,
                    ),
                    _DropdownOption(
                      value: VisitTimingFilter.early,
                      label: context.s.filterTimingEarly,
                      icon: Icons.fast_rewind_rounded,
                    ),
                    _DropdownOption(
                      value: VisitTimingFilter.overdue,
                      label: context.s.filterTimingOverdue,
                      icon: Icons.warning_amber_rounded,
                    ),
                  ],
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    context
                        .read<VisitsListBloc>()
                        .add(VisitsListTimingFilterChanged(v));
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One option in `_FilterDropdown`. Carries the value, its label, and
/// an icon for the menu item.
class _DropdownOption<T> {
  final T value;
  final String label;
  final IconData icon;
  const _DropdownOption({
    required this.value,
    required this.label,
    required this.icon,
  });
}

/// Pill-shaped dropdown used for the admin's Status + Timing slicers.
/// Renders `label • currentValue` inside a chip and opens a menu on
/// tap. When the current value isn't the default, the chip switches
/// to the primary color so the admin can see an active filter at a
/// glance.
class _FilterDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final bool isDefault;
  final List<_DropdownOption<T>> options;
  final ValueChanged<T> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.isDefault,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final current = options.firstWhere(
      (o) => o.value == value,
      orElse: () => options.first,
    );
    final fg = isDefault ? colors.onSurfaceVariant : colors.onPrimary;
    final bg = isDefault ? colors.surfaceContainerHighest : colors.primary;
    return PopupMenuButton<T>(
      initialValue: value,
      onSelected: onChanged,
      tooltip: label,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      itemBuilder: (ctx) => [
        for (final o in options)
          PopupMenuItem<T>(
            value: o.value,
            child: Row(
              children: [
                Icon(o.icon, size: 18, color: ctx.colors.primary),
                const SizedBox(width: 10),
                Text(o.label),
                const Spacer(),
                if (o.value == value)
                  Icon(Icons.check_rounded,
                      size: 18, color: ctx.colors.primary),
              ],
            ),
          ),
      ],
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(current.icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$label  ',
                      style: TextStyle(
                        color: fg.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                    TextSpan(
                      text: current.label,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.expand_more_rounded, size: 18, color: fg),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: selected ? colors.primary : colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? colors.onPrimary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color:
                      selected ? colors.onPrimary : colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loading state for the visits list — mirrors the rough shape of a
/// `VisitCard` (top badge row, title + customer subtitle, timeline strip
/// and footer button) so the swap to real data feels stable.
class _VisitsSkeleton extends StatelessWidget {
  const _VisitsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Row(
                children: [
                  SkeletonBox(width: 90, height: 22, radius: 12),
                  Spacer(),
                  SkeletonBox(width: 70, height: 12),
                ],
              ),
              SizedBox(height: 14),
              Row(
                children: [
                  SkeletonCircle(size: 38),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 140, height: 14),
                        SizedBox(height: 6),
                        SkeletonBox(width: 90, height: 11),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14),
              SkeletonBox(width: double.infinity, height: 56, radius: 8),
              SizedBox(height: 12),
              SkeletonBox(width: double.infinity, height: 14, radius: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Identifies the time bucket a visit belongs to for the grouped list.
/// Order maps to the on-screen sort: upcoming groups appear first (newest
/// future), then today's running/completed visits, then history descending.
enum _VisitGroup {
  upcoming,
  laterThisWeek,
  tomorrow,
  today,
  yesterday,
  earlierThisWeek,
  earlier,
}

/// Picks a bucket for a single visit based on its `visitDate`, falling
/// back to `checkInTime` and finally to the "today" bucket for drafts
/// without any date info.
_VisitGroup _bucketFor(Visit v, DateTime todayStart) {
  // Same priority as the Today filter — use the actual execution date
  // (check-out > check-in > scheduled). Keeps the group label honest
  // when a visit ran earlier or later than originally scheduled.
  final ref = v.effectiveDate;
  if (ref == null) return _VisitGroup.today;
  final refDay = DateTime(ref.year, ref.month, ref.day);
  final delta = refDay.difference(todayStart).inDays;
  if (delta > 7) return _VisitGroup.upcoming;
  if (delta > 1) return _VisitGroup.laterThisWeek;
  if (delta == 1) return _VisitGroup.tomorrow;
  if (delta == 0) return _VisitGroup.today;
  if (delta == -1) return _VisitGroup.yesterday;
  if (delta >= -7) return _VisitGroup.earlierThisWeek;
  return _VisitGroup.earlier;
}

String _groupLabel(BuildContext context, _VisitGroup g) {
  final s = context.s;
  switch (g) {
    case _VisitGroup.upcoming:
      return s.groupUpcoming;
    case _VisitGroup.laterThisWeek:
      return s.groupLaterThisWeek;
    case _VisitGroup.tomorrow:
      return s.groupTomorrow;
    case _VisitGroup.today:
      return s.groupToday;
    case _VisitGroup.yesterday:
      return s.groupYesterday;
    case _VisitGroup.earlierThisWeek:
      return s.groupEarlierThisWeek;
    case _VisitGroup.earlier:
      return s.groupEarlier;
  }
}

/// Renders the visits list with optional date-group headers and a small
/// stats card at the top. The list is one flat `ListView` of mixed item
/// types (header / card) so scroll position stays stable when items move
/// between buckets after a refresh.
class _GroupedList extends StatelessWidget {
  final List<Visit> visits;
  final bool showGroups;
  final String searchQuery;

  const _GroupedList({
    super.key,
    required this.visits,
    required this.showGroups,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    // Sort each candidate visit so active rises to the top within its
    // bucket. After that, order by `effectiveDate` descending — that
    // means completed visits sort by their actual check-out time, not
    // the scheduled day they were created for.
    int sortKey(Visit a, Visit b) {
      final activeA = a.state == VisitStateType.checkedIn ? 1 : 0;
      final activeB = b.state == VisitStateType.checkedIn ? 1 : 0;
      if (activeA != activeB) return activeB.compareTo(activeA);
      final ta = a.effectiveDate ?? DateTime(1970);
      final tb = b.effectiveDate ?? DateTime(1970);
      return tb.compareTo(ta);
    }

    final entries = <_ListEntry>[];
    if (showGroups) {
      final byGroup = <_VisitGroup, List<Visit>>{};
      for (final v in visits) {
        byGroup.putIfAbsent(_bucketFor(v, todayStart), () => []).add(v);
      }
      // Iterate groups in enum order so headers render top-to-bottom in
      // the intended sequence (upcoming → past).
      for (final g in _VisitGroup.values) {
        final bucket = byGroup[g];
        if (bucket == null || bucket.isEmpty) continue;
        bucket.sort(sortKey);
        entries.add(_HeaderEntry(_groupLabel(context, g), bucket.length));
        for (final v in bucket) {
          entries.add(_CardEntry(v));
        }
      }
    } else {
      final sorted = [...visits]..sort(sortKey);
      for (final v in sorted) {
        entries.add(_CardEntry(v));
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: entries.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: _StatsBar(
              visits: visits,
              onStatTap: (filter) => context
                  .read<VisitsListBloc>()
                  .add(VisitsListStatusFilterChanged(filter)),
            ),
          );
        }
        final entry = entries[i - 1];
        if (entry is _HeaderEntry) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
            child: Row(
              children: [
                Text(
                  entry.label,
                  style: context.text.labelMedium?.copyWith(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${entry.count}',
                    style: context.text.labelSmall?.copyWith(
                      color: context.colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        final card = (entry as _CardEntry).visit;
        final isAdmin =
            context.read<AuthBloc>().state.user?.canEditVisits ?? false;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AnimatedListItem(
            index: i,
            child: VisitCard(
              visit: card,
              highlight: searchQuery,
              showEmployee: isAdmin,
              onTap: () => context.push('/visits/${card.id}', extra: card),
            ),
          ),
        );
      },
    );
  }
}

sealed class _ListEntry {}

class _HeaderEntry extends _ListEntry {
  final String label;
  final int count;
  _HeaderEntry(this.label, this.count);
}

class _CardEntry extends _ListEntry {
  final Visit visit;
  _CardEntry(this.visit);
}

/// Compact summary card above the list. For non-admins it shows
/// `total / active / completed`. For admins we split "completed" into
/// "Pending review" (amber, work the employee finished but the admin
/// hasn't approved) + "Done" (green) — that's where the admin's
/// remaining work lives, so it deserves its own number.
///
/// Each cell on the admin variant is tappable: tap "Pending review"
/// and the Status dropdown filter snaps to that bucket so the admin
/// can drill in instantly.
class _StatsBar extends StatelessWidget {
  final List<Visit> visits;
  final ValueChanged<VisitStatusFilter>? onStatTap;
  const _StatsBar({required this.visits, this.onStatTap});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthBloc>().state.user;
    final isAdmin = user?.canEditVisits ?? false;
    final total = visits.length;
    final active = visits
        .where((v) => v.state == VisitStateType.checkedIn)
        .length;
    final colors = context.colors;
    final pending = visits
        .where((v) => v.lifecycleState == VisitLifecycleState.underReview)
        .length;
    final done = visits
        .where((v) => v.lifecycleState == VisitLifecycleState.done)
        .length;
    final completed = visits
        .where((v) => v.state == VisitStateType.checkedOut)
        .length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary.withValues(alpha: 0.08),
            colors.tertiary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatCell(
              label: context.s.statsTotal,
              value: total,
              color: colors.primary,
              icon: Icons.event_note_rounded,
            ),
          ),
          _StatDivider(),
          Expanded(
            child: _StatCell(
              label: context.s.statsActive,
              value: active,
              color: Colors.green.shade600,
              icon: Icons.bolt_rounded,
            ),
          ),
          if (isAdmin) ...[
            _StatDivider(),
            Expanded(
              child: _StatCell(
                label: context.s.statsPendingReview,
                value: pending,
                color: Colors.amber.shade700,
                icon: Icons.rate_review_rounded,
                onTap: pending > 0 && onStatTap != null
                    ? () => onStatTap!(VisitStatusFilter.pendingReview)
                    : null,
                highlight: pending > 0,
              ),
            ),
            _StatDivider(),
            Expanded(
              child: _StatCell(
                label: context.s.statsDone,
                value: done,
                color: colors.tertiary,
                icon: Icons.check_circle_rounded,
                onTap: done > 0 && onStatTap != null
                    ? () => onStatTap!(VisitStatusFilter.completed)
                    : null,
              ),
            ),
          ] else ...[
            _StatDivider(),
            Expanded(
              child: _StatCell(
                label: context.s.statsCompleted,
                value: completed,
                color: colors.tertiary,
                icon: Icons.check_circle_rounded,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  /// When non-null, the cell becomes a tap target (used for the
  /// admin's "Pending review" / "Done" cells to jump-filter the list).
  final VoidCallback? onTap;
  /// Boost visual weight when there's actionable work in the bucket
  /// (currently only used by the Pending Review cell when count > 0).
  final bool highlight;
  const _StatCell({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              '$value',
              style: context.text.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: context.text.labelSmall?.copyWith(
            color: context.colors.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
    if (onTap == null) return body;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap!();
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: highlight
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 4),
                  child: body,
                ),
              )
            : body,
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: context.colors.outlineVariant,
    );
  }
}
