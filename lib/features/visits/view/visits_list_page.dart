import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';

import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/visit_card.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/data/models/user.dart';
import '../bloc/visits_list_bloc.dart';
import '../data/models/visit.dart';
import '../../../app/design/app_dimens.dart';
import '../../../shared/widgets/app_refresh_indicator.dart';

/// Primary visits screen. Field users see only their own visits (REST `/my`);
/// managers get Pending / Team (and Escalated for project managers) tabs read
/// via `call_kw` — Odoo record rules scope them to the manager's hierarchy.
class VisitsListPage extends StatefulWidget {
  const VisitsListPage({super.key});

  @override
  State<VisitsListPage> createState() => _VisitsListPageState();
}

class _VisitsListPageState extends State<VisitsListPage> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<VisitsListBloc>();
      if (bloc.state.status == VisitsListStatus.initial) {
        final user = context.read<AuthBloc>().state.user;
        final scope = (user?.canEditVisits ?? false)
            ? VisitListScope.pending
            : VisitListScope.mine;
        bloc.add(VisitsListLoadRequested(scope: scope));
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<VisitListScope> _scopesFor(AuthUser? user) {
    if (user == null || !user.canEditVisits) return [VisitListScope.mine];
    return [
      VisitListScope.pending,
      VisitListScope.team,
      VisitListScope.mine,
      if (user.canSeeEscalated) VisitListScope.escalated,
    ];
  }

  String _scopeLabel(BuildContext context, VisitListScope s) {
    switch (s) {
      case VisitListScope.mine:
        return context.s.wfScopeMine;
      case VisitListScope.pending:
        return context.s.wfScopePending;
      case VisitListScope.team:
        return context.s.wfScopeTeam;
      case VisitListScope.escalated:
        return context.s.wfScopeEscalated;
    }
  }

  String _emptyLabel(BuildContext context, VisitListScope s) {
    switch (s) {
      case VisitListScope.mine:
        return context.s.wfEmptyMine;
      case VisitListScope.pending:
        return context.s.wfEmptyPending;
      case VisitListScope.team:
        return context.s.wfEmptyTeam;
      case VisitListScope.escalated:
        return context.s.wfEmptyEscalated;
    }
  }

  List<Visit> _filter(VisitsListState state) {
    final q = state.searchQuery.trim().toLowerCase();
    return state.items.where((v) {
      if (state.stateFilter != null && v.state != state.stateFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return (v.partnerName ?? '').toLowerCase().contains(q) ||
          (v.name ?? '').toLowerCase().contains(q) ||
          (v.purpose ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthBloc>().state.user;
    final scopes = _scopesFor(user);

    return BlocBuilder<VisitsListBloc, VisitsListState>(
      builder: (context, state) {
        final bloc = context.read<VisitsListBloc>();
        final visits = _filter(state);
        return Column(
          children: [
            if (scopes.length > 1)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    for (final s in scopes)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: ChoiceChip(
                          label: Text(_scopeLabel(context, s)),
                          selected: state.scope == s,
                          onSelected: (_) =>
                              bloc.add(VisitsListScopeChanged(s)),
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: context.s.wfSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                ),
                onChanged: (q) => bloc.add(VisitsListSearchChanged(q)),
              ),
            ),
            Expanded(
              child: _content(context, state, visits, bloc),
            ),
          ],
        );
      },
    );
  }

  Widget _content(
    BuildContext context,
    VisitsListState state,
    List<Visit> visits,
    VisitsListBloc bloc,
  ) {
    if (state.status == VisitsListStatus.loading) {
      return const SkeletonList(itemCount: 6);
    }
    if (state.status == VisitsListStatus.failure) {
      return ErrorView(
        message: state.error?.localize(context) ?? context.s.errUnknown,
        onRetry: () => bloc.add(const VisitsListLoadRequested()),
      );
    }
    if (visits.isEmpty) {
      return EmptyView(
        icon: Icons.event_note_outlined,
        message: _emptyLabel(context, state.scope),
      );
    }
    final showEmployee = state.scope != VisitListScope.mine;
    return AppRefreshIndicator(
      onRefresh: () async => bloc.add(const VisitsListLoadRequested()),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
        itemCount: visits.length,
        itemBuilder: (ctx, i) {
          final v = visits[i];
          return VisitCard(
            visit: v,
            showEmployee: showEmployee,
            onTap: () => ctx.push(AppRoutes.visitDetail(v.id), extra: v),
          );
        },
      ),
    );
  }
}
