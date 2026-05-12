import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
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
    context
        .read<VisitsListBloc>()
        .add(const VisitsListLoadRequested());
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
        Expanded(
          child: BlocBuilder<VisitsListBloc, VisitsListState>(
            builder: (context, state) {
              if (state.status == VisitsListStatus.loading) {
                return _HistorySkeleton();
              }
              if (state.status == VisitsListStatus.failure &&
                  state.items.isEmpty) {
                return ErrorView(
                  message: state.error?.localize(context) ??
                      context.s.errUnknown,
                  onRetry: _refresh,
                );
              }
              // Apply client-side Today/All filter first. The backend's
              // date_from/date_to params still don't work (see open
              // ask §9), so we filter here on `visitDate` (enriched via
              // call_kw, see VisitsRepository.list). "All" shows every
              // visit the backend gave us — past, today, and upcoming.
              final now = DateTime.now();
              final todayStart = DateTime(now.year, now.month, now.day);
              final todayEnd =
                  todayStart.add(const Duration(days: 1));
              bool isToday(DateTime d) =>
                  !d.isBefore(todayStart) && d.isBefore(todayEnd);
              final dateFiltered = state.filter == VisitsFilter.all
                  ? state.items
                  : state.items.where((v) {
                      // Prefer the explicit scheduled date when known.
                      if (v.visitDate != null) return isToday(v.visitDate!);
                      // Fall back to check-in time for visits in progress
                      // or completed today.
                      final t = v.checkInTime;
                      if (t != null) return isToday(t);
                      // Last resort (visitDate not yet shipped by backend
                      // and no check-in yet): keep draft visible.
                      return true;
                    }).toList();

              // Then apply the search box on top.
              final q = state.searchQuery.toLowerCase();
              final searched = q.isEmpty
                  ? dateFiltered
                  : dateFiltered
                      .where((v) =>
                          (v.customerName ?? '').toLowerCase().contains(q))
                      .toList();
              if (searched.isEmpty) {
                final msg = q.isNotEmpty
                    ? context.s.pickerNoResults
                    : state.filter == VisitsFilter.today
                        ? context.s.visitsTodayEmpty
                        : context.s.visitsHistoryEmpty;
                return ListView(
                  children: [
                    const SizedBox(height: 80),
                    EmptyView(
                      icon: Icons.event_busy_outlined,
                      message: msg,
                    ),
                  ],
                );
              }
              // Active first, then by most recent check-in.
              final sorted = [...searched]..sort((a, b) {
                  final activeA =
                      a.state == VisitStateType.checkedIn ? 1 : 0;
                  final activeB =
                      b.state == VisitStateType.checkedIn ? 1 : 0;
                  if (activeA != activeB) return activeB.compareTo(activeA);
                  final ta = a.checkInTime ?? DateTime(1970);
                  final tb = b.checkInTime ?? DateTime(1970);
                  return tb.compareTo(ta);
                });
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final v = sorted[i];
                    return VisitCard(
                      visit: v,
                      onTap: () => context.push('/visits/${v.id}', extra: v),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
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
                onTap: () => context
                    .read<VisitsListBloc>()
                    .add(const VisitsListFilterChanged(VisitsFilter.today)),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: context.s.visitsFilterAll,
                icon: Icons.all_inclusive_rounded,
                selected: state.filter == VisitsFilter.all,
                onTap: () => context
                    .read<VisitsListBloc>()
                    .add(const VisitsListFilterChanged(VisitsFilter.all)),
              ),
            ],
          );
        },
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

class _HistorySkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => const SkeletonCard(height: 150),
      ),
    );
  }
}
