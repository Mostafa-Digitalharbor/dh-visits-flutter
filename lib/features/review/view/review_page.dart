import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/design/app_decor.dart';
import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/utils/user_time.dart';
import '../../../shared/extensions/bloc_extensions.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../dashboard/view/visits_list_feedback.dart';
import '../../visits/bloc/visits_list_bloc.dart';
import '../../visits/data/models/visit.dart';
import '../../visits/data/visits_repository.dart';
import '../../visits/view/action_sheets.dart';
import '../../visits/view/visit_labels.dart';

/// Manager review queue (design screen 09). Lists every visit in the
/// `under_review` lifecycle as an approve/reject card. Approving writes
/// `state = done`; rejecting writes `state = submit` so the employee redoes it.
///
/// The queue has a list bloc of its own, always on the `pending` scope. It used
/// to filter the app-wide list, which shows whatever chip the Visits tab was
/// left on — an "escalated" chip turned this screen into a false "nothing to
/// review" — and each decision then switched that tab's chip under the user.
class ReviewPage extends StatelessWidget {
  /// Builds the page's list bloc. Tests pass a seeded one; the app leaves it
  /// null for a fresh bloc on the visits repository.
  final VisitsListBloc Function()? createBloc;

  const ReviewPage({super.key, this.createBloc});

  @override
  Widget build(BuildContext context) {
    // The app-wide list, refreshed after each decision so the Visits tab does
    // not keep showing a visit that is no longer waiting.
    final appList = context.read<VisitsListBloc>();
    return BlocProvider<VisitsListBloc>(
      create: (_) => (createBloc?.call() ??
          VisitsListBloc(repository: sl<VisitsRepository>()))
        ..add(const VisitsListLoadRequested(scope: VisitListScope.pending)),
      child: _ReviewView(
        onDecided: () => appList.add(const VisitsListLoadRequested()),
      ),
    );
  }
}

class _ReviewView extends StatefulWidget {
  final VoidCallback onDecided;
  const _ReviewView({required this.onDecided});

  @override
  State<_ReviewView> createState() => _ReviewViewState();
}

class _ReviewViewState extends State<_ReviewView> {
  bool _busy = false;

  /// Visits decided here that the reload has not dropped yet. Hidden at once,
  /// so a second tap cannot try to decide the same visit twice.
  final Set<int> _decided = {};

  Future<void> _refresh() {
    final bloc = context.read<VisitsListBloc>()
      ..add(const VisitsListLoadRequested(scope: VisitListScope.pending));
    return bloc.untilSettled((s) => s.status == VisitsListStatus.loading);
  }

  Future<void> _decide(Visit visit,
      {required bool approve, String? reason}) async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    try {
      final repo = sl<VisitsRepository>();
      if (approve) {
        await repo.approve(visit.id);
      } else {
        await repo.reject(visit.id, reason ?? '');
      }
      if (!mounted) return;
      setState(() => _decided.add(visit.id));
      widget.onDecided();
      unawaited(_refresh());
      context.showSnack(
        approve ? context.s.reviewApproved : context.s.reviewRejected,
        kind: approve ? SnackKind.success : SnackKind.info,
      );
    } on ApiException catch (e) {
      if (mounted) context.showSnack(e.localize(context), kind: SnackKind.error);
    } catch (e) {
      appLog('[ReviewPage] decision on visit ${visit.id} failed: $e');
      if (mounted) {
        context.showSnack(context.s.errActionFailed, kind: SnackKind.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(Visit visit) async {
    final reason = await showRejectReasonSheet(context);
    if (reason == null || !mounted) return;
    await _decide(visit, approve: false, reason: reason);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CvSubAppBar(
        title: context.s.reviewTitle,
        eyebrow: context.s.roleManagerTitle,
        topInset: MediaQuery.paddingOf(context).top,
      ),
      body: VisitsRefreshFailureListener(
        child: BlocConsumer<VisitsListBloc, VisitsListState>(
          listenWhen: (p, c) =>
              c.status == VisitsListStatus.success &&
              p.status != VisitsListStatus.success,
          // Once the server's list no longer has a decided visit, it needs no
          // hiding any more.
          listener: (_, state) => _decided.retainWhere(
              (id) => state.items.any((v) => v.id == id)),
          builder: (context, state) {
            if (state.items.isEmpty &&
                (state.status == VisitsListStatus.loading ||
                    state.status == VisitsListStatus.initial)) {
              return const SkeletonList();
            }
            // Check failure before empty: otherwise a failed fetch renders
            // "nothing to approve" and the manager closes the app while visits
            // sit waiting. Wrong information is worse than none.
            if (state.status == VisitsListStatus.failure &&
                state.items.isEmpty) {
              return ErrorView(
                message: state.error?.localize(context) ?? context.s.errUnknown,
                onRetry: _refresh,
              );
            }
            final pending = [
              for (final v in state.items)
                if (v.isAwaitingApproval && !_decided.contains(v.id)) v,
            ];
            return AppRefreshIndicator(
              onRefresh: _refresh,
              child: pending.isEmpty
                  ? RefreshableEmptyView(
                      icon: Symbols.task_alt,
                      message: context.s.reviewEmpty,
                    )
                  : _ReviewList(
                      pending: pending,
                      busy: _busy,
                      onApprove: (v) => _decide(v, approve: true),
                      onReject: _reject,
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _ReviewList extends StatelessWidget {
  final List<Visit> pending;
  final bool busy;
  final ValueChanged<Visit> onApprove;
  final ValueChanged<Visit> onReject;
  const _ReviewList({
    required this.pending,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final edge = context.r(Insets.screen);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // An explicit padding drops the list's automatic bottom inset, so the
      // home indicator is added back: the last card's buttons sit above it.
      padding: EdgeInsets.fromLTRB(
        edge,
        edge,
        edge,
        context.r(Insets.x6) + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Center(child: _PendingChip(count: pending.length)),
        context.gapH(Insets.x3h),
        for (final v in pending) ...[
          _ReviewCard(
            visit: v,
            busy: busy,
            onApprove: () => onApprove(v),
            onReject: () => onReject(v),
          ),
          context.gapH(Insets.x3h),
        ],
      ],
    );
  }
}

class _PendingChip extends StatelessWidget {
  final int count;
  const _PendingChip({required this.count});

  @override
  Widget build(BuildContext context) {
    final x = context.x;
    // FittedBox, not an ellipsis: this chip is the headline of the screen —
    // "3 visits waiting for your review". On a 320dp phone at the largest text
    // scale the Arabic string is wider than the row, and "3 visits waiting
    // for…" answers nothing. Scaling keeps the sentence readable where it has
    // to shrink and full size everywhere else.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: TonePill(
        label: context.s.reviewPendingCount(count),
        icon: Symbols.pending,
        color: x.warning,
        foreground: x.onWarningContainer,
        tintAlpha: Alphas.halo,
        fontSize: FontSz.base,
        iconSize: IconSz.xs,
        padding: context.padSym(h: Insets.x3h, v: Insets.x1h),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Visit visit;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  const _ReviewCard(
      {required this.visit, required this.busy, required this.onApprove, required this.onReject});

  // TODO(backend): surface the mock-location flag on this card once `dh.visit`
  // has a real indexed `is_mocked` column.
  //
  // The mock-location verdict IS recorded (see
  // `VisitsRepository.hasMockLocationFlag`) and rendered on the visit *detail*
  // page — but this is a list, and the flag lives on the chatter, so showing it
  // per card would cost one round trip per row. The column is the outstanding
  // backend ask that makes it a single query.

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final cs = context.colors;
    final x = context.x;
    final timeFmt = AppDate.timeFormat(context);
    String timeOf(DateTime? utc) =>
        utc == null ? s.commonNoValue : timeFmt.format(context.toUserTime(utc));
    final delta = visit.executionDaysDelta;
    final onTimeColor = delta == null
        ? x.textTertiary
        : delta == 0
            ? x.success
            : x.warning;
    final duration = visit.visitDuration;
    final metaStyle = TextStyle(
      fontSize: FontSz.sm,
      fontWeight: FontWeight.w600,
      color: x.textTertiary,
    );

    return Container(
      padding: context.padAll(Insets.x3h),
      decoration: AppDecor.panel(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Identity + meta — tapping opens the full visit detail so the
          // manager can review everything before deciding.
          InkWell(
            borderRadius: BorderRadius.circular(Radii.sm),
            onTap: () => context.push(
              AppRoutes.visitDetail(visit.id),
              extra: visit,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    InitialAvatar(
                      name: visit.customerName,
                      icon: Symbols.business,
                      size: context.r(CompSz.avatar),
                    ),
                    context.gapW(Insets.x3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(visit.displayTitle(context),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.cardTitle
                                  .copyWith(color: cs.onSurface)),
                          context.gapH(Insets.hair),
                          Text(
                            context.joinFacts([
                              visit.displayReference(context),
                              visit.visitTypeName,
                            ]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: metaStyle,
                          ),
                        ],
                      ),
                    ),
                    if (duration != null) ...[
                      context.gapW(Insets.x1),
                      TonePill(
                        label: duration.clock,
                        icon: Symbols.timer,
                        color: cs.onSurfaceVariant,
                        tintAlpha: Alphas.tint,
                        fontSize: FontSz.sm,
                        iconSize: IconSz.meta,
                        padding: context.padSym(h: Insets.x2, v: Insets.x1),
                      ),
                    ],
                    context.gapW(Insets.x1),
                    // Mirrors itself in RTL.
                    Icon(
                      Icons.chevron_right,
                      size: context.r(IconSz.label),
                      color: x.textTertiary,
                    ),
                  ],
                ),
                context.gapH(Insets.x3),
                // Meta strip
                Container(
                  padding: context.padSym(h: Insets.x3, v: Insets.x2),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainer,
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: Row(
                    children: [
                      Icon(Symbols.person,
                          size: context.r(IconSz.pill), color: x.textTertiary),
                      context.gapW(Insets.x1),
                      Expanded(
                        child: Text(visit.employeeName ?? s.commonNoValue,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: FontSz.sm,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurfaceVariant)),
                      ),
                      context.gapW(Insets.x1),
                      Icon(Symbols.check_circle,
                          fill: 1,
                          size: context.r(IconSz.inline),
                          color: onTimeColor),
                      context.gapW(Insets.x1),
                      Text(
                        s.commonTimeRange(
                          timeOf(visit.checkInTime),
                          timeOf(visit.checkOutTime),
                        ),
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: FontSz.sm,
                          fontWeight: FontWeight.w800,
                          color: onTimeColor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          context.gapH(Insets.x3),
          // Actions
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: s.reviewReject,
                  icon: Symbols.close,
                  bg: cs.errorContainer,
                  fg: cs.error,
                  onTap: busy ? null : onReject,
                ),
              ),
              context.gapW(Insets.x2h),
              Expanded(
                flex: _approveFlex,
                child: _ActionButton(
                  label: s.reviewApprove,
                  icon: Symbols.check,
                  bg: x.success,
                  // The card surface reads on the success hue in both themes.
                  fg: cs.surfaceContainerLowest,
                  glow: x.glowSuccess,
                  onTap: busy ? null : onApprove,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Approve takes three quarters of the action row: it is the common answer.
  static const int _approveFlex = 3;
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
  final List<BoxShadow>? glow;
  final VoidCallback? onTap;
  const _ActionButton(
      {required this.label, required this.icon, required this.bg, required this.fg, this.glow, this.onTap});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(Radii.btn);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: glow),
      child: Material(
        color: bg,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            height: context.fixedH(IconSz.hit),
            alignment: Alignment.center,
            padding: context.padSym(h: Insets.x2),
            // Scale the label down rather than ellipsise it. Reject gets a
            // quarter of this row, which on a 320dp screen at the largest text
            // scale clipped it to "Re…" — an unreadable stub on the
            // *destructive* action, where mistaking it for anything else
            // rejects a colleague's visit.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, fill: 1, size: context.r(IconSz.label), color: fg),
                  context.gapW(Insets.x1h),
                  Text(label,
                      maxLines: 1,
                      style: AppType.button
                          .copyWith(fontWeight: FontWeight.w800, color: fg)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
