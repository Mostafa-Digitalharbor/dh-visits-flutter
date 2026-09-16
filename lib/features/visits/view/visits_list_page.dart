import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design/app_dimens.dart';
import '../../../app/design/responsive.dart';
import '../../../app/routes.dart';
import '../../../shared/extensions/bloc_extensions.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_refresh_indicator.dart';
import '../../../shared/widgets/debounced_search_field.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/visit_card.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/data/models/user.dart';
import '../bloc/visits_list_bloc.dart';

/// Primary visits screen. Field users see only their own visits (REST `/my`);
/// managers get Pending / Team (and Escalated for project managers) tabs read
/// via `call_kw` — Odoo record rules scope them to the manager's hierarchy.
class VisitsListPage extends StatefulWidget {
  const VisitsListPage({super.key});

  @override
  State<VisitsListPage> createState() => _VisitsListPageState();
}

class _VisitsListPageState extends State<VisitsListPage> {
  /// Room under the last card for the floating create button and the running
  /// visit bar, so neither covers it.
  static const double _bottomClearance = 90;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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

  /// Reloads and keeps the pull-to-refresh spinner up until the answer is in.
  Future<void> _refresh(VisitsListBloc bloc) {
    bloc.add(const VisitsListLoadRequested());
    return bloc.untilSettled((s) => s.status == VisitsListStatus.loading);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthBloc>().state.user;
    final scopes = _scopesFor(user);
    final gutter = context.r(Insets.x3);

    return BlocListener<VisitsListBloc, VisitsListState>(
      // A refresh that fails over rows already on screen keeps them — but the
      // user asked for fresh data and must hear that they didn't get it.
      listenWhen: (p, c) =>
          c.status == VisitsListStatus.failure &&
          p.status != VisitsListStatus.failure &&
          c.items.isNotEmpty,
      listener: (context, state) {
        final error = state.error;
        if (error != null) {
          context.showSnack(error.localize(context), kind: SnackKind.error);
        }
      },
      child: Column(
        children: [
          // Outside the builder below: the chips only depend on `scope`, and
          // the search box owns a `TextField` whose controller must not be
          // rebuilt on every list emit.
          if (scopes.length > 1)
            BlocSelector<VisitsListBloc, VisitsListState, VisitListScope>(
              selector: (s) => s.scope,
              builder: (context, scope) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsetsDirectional.fromSTEB(
                  gutter,
                  context.r(Insets.x2),
                  gutter,
                  0,
                ),
                child: Row(
                  children: [
                    for (final s in scopes)
                      Padding(
                        padding: EdgeInsetsDirectional.only(
                          end: context.r(Insets.x2),
                        ),
                        child: ChoiceChip(
                          label: Text(_scopeLabel(context, s)),
                          selected: scope == s,
                          onSelected: (_) => context.read<VisitsListBloc>().add(
                            VisitsListScopeChanged(s),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          // Debounced like the customers screen. A raw `onChanged` fired a
          // bloc event per keystroke, and each emit re-filtered every row and
          // rebuilt the whole list — the worst typing latency in the app on a
          // slow phone.
          DebouncedSearchField(
            padding: EdgeInsetsDirectional.fromSTEB(
              gutter,
              context.r(Insets.x2),
              gutter,
              context.r(Insets.x1),
            ),
            hintText: context.s.wfSearchHint,
            onChanged: (q) =>
                context.read<VisitsListBloc>().add(VisitsListSearchChanged(q)),
          ),
          const _FocusChip(),
          Expanded(
            child: BlocBuilder<VisitsListBloc, VisitsListState>(
              builder: (context, state) => _content(context, state),
            ),
          ),
        ],
      ),
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
      // A search or filter that matches nothing is not an empty queue —
      // saying "no visits assigned to you" there reads as data loss.
      final message = state.searchQuery.trim().isNotEmpty
          ? context.s.wfSearchNoMatch
          : state.isFiltered
          ? context.s.wfFilterNoMatch
          : _emptyLabel(context, state.scope);
      // Scrollable so the empty state can still be pulled to refresh — it is
      // the screen where a user most wants to check again.
      return AppRefreshIndicator(
        onRefresh: () => _refresh(bloc),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: EmptyView(
                icon: Icons.event_note_outlined,
                message: message,
              ),
            ),
          ),
        ),
      );
    }
    final showEmployee = state.scope != VisitListScope.mine;
    final gutter = context.r(Insets.x3);
    return AppRefreshIndicator(
      onRefresh: () => _refresh(bloc),
      child: ListView.builder(
        padding: EdgeInsetsDirectional.fromSTEB(
          gutter,
          context.r(Insets.x1),
          gutter,
          context.fixedH(_bottomClearance),
        ),
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

/// The dashboard preset the list was opened with, as a chip the user can
/// remove. Without it the list silently showed a subset, and a rep could not
/// tell why visits they knew about were missing.
class _FocusChip extends StatelessWidget {
  const _FocusChip();

  static String? _label(BuildContext context, VisitsListFocus focus) =>
      switch (focus) {
        VisitsListFocus.all => null,
        VisitsListFocus.overdue => context.s.dashboardKpiOverdue,
        VisitsListFocus.today => context.s.dashboardKpiToday,
        VisitsListFocus.inProgress => context.s.dashboardKpiActive,
      };

  @override
  Widget build(BuildContext context) {
    return BlocSelector<VisitsListBloc, VisitsListState, VisitsListFocus>(
      selector: (s) => s.focus,
      builder: (context, focus) {
        final label = _label(context, focus);
        if (label == null) return const SizedBox.shrink();
        final gutter = context.r(Insets.x3);
        return Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            gutter,
            0,
            gutter,
            context.r(Insets.x1),
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: InputChip(
              avatar: const Icon(Icons.filter_alt_outlined),
              label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              selected: true,
              showCheckmark: false,
              deleteButtonTooltipMessage: context.s.wfClearFilter,
              onDeleted: () => context.read<VisitsListBloc>().add(
                const VisitsListFocusChanged(VisitsListFocus.all),
              ),
            ),
          ),
        );
      },
    );
  }
}
