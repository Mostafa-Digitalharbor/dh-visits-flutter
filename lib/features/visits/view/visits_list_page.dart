import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';

import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/debounced_search_field.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/visit_card.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/data/models/user.dart';
import '../bloc/visits_list_bloc.dart';
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

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthBloc>().state.user;
    final scopes = _scopesFor(user);

    return Column(
      children: [
        // Outside the builder below: the chips only depend on `scope`, and the
        // search box owns a `TextField` whose controller must not be rebuilt
        // on every list emit.
        if (scopes.length > 1)
          BlocSelector<VisitsListBloc, VisitsListState, VisitListScope>(
            selector: (s) => s.scope,
            builder: (context, scope) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  for (final s in scopes)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(
                        label: Text(_scopeLabel(context, s)),
                        selected: scope == s,
                        onSelected: (_) => context
                            .read<VisitsListBloc>()
                            .add(VisitsListScopeChanged(s)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        // Debounced like the customers screen. A raw `onChanged` fired a bloc
        // event per keystroke, and each emit re-filtered every row and rebuilt
        // the whole list — the worst typing latency in the app on a slow phone.
        DebouncedSearchField(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          hintText: context.s.wfSearchHint,
          onChanged: (q) =>
              context.read<VisitsListBloc>().add(VisitsListSearchChanged(q)),
        ),
        Expanded(
          child: BlocBuilder<VisitsListBloc, VisitsListState>(
            builder: (context, state) => _content(context, state),
          ),
        ),
      ],
    );
  }

  Widget _content(BuildContext context, VisitsListState state) {
    final bloc = context.read<VisitsListBloc>();
    final visits = state.visible;

    // `&& items.isEmpty` on both guards: a pull-to-refresh over a populated
    // list used to replace it with a skeleton and then, if the refresh failed,
    // with a full-screen error — throwing away rows the user was reading. Now
    // only a first load (nothing to show yet) takes the screen over.
    if (state.status == VisitsListStatus.loading && state.items.isEmpty) {
      return const SkeletonList(itemCount: 6);
    }
    if (state.status == VisitsListStatus.failure && state.items.isEmpty) {
      return ErrorView(
        message: state.error?.localize(context) ?? context.s.errUnknown,
        onRetry: () => bloc.add(const VisitsListLoadRequested()),
      );
    }
    if (visits.isEmpty) {
      return EmptyView(
        icon: Icons.event_note_outlined,
        // A search that matches nothing is not an empty queue — saying "no
        // visits assigned to you" there reads as data loss.
        message: state.searchQuery.trim().isEmpty
            ? _emptyLabel(context, state.scope)
            : context.s.wfSearchNoMatch,
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
            key: ValueKey(v.id),
            visit: v,
            showEmployee: showEmployee,
            onTap: () => ctx.push(AppRoutes.visitDetail(v.id), extra: v),
          );
        },
      ),
    );
  }
}
