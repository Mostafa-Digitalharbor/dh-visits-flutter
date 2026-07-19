import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/user_time.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../visits/bloc/visits_list_bloc.dart';
import '../../visits/data/models/visit.dart';
import '../../visits/data/visits_repository.dart';
import '../../visits/view/action_sheets.dart';
import '../../../core/utils/duration_format.dart';

/// Manager review queue (design screen 09). Lists every visit in the
/// `under_review` lifecycle as an approve/reject card. Approving writes
/// `state = done`; rejecting writes `state = submit` so the employee redoes it.
class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  bool _busy = false;

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
      context
          .read<VisitsListBloc>()
          .add(const VisitsListLoadRequested(scope: VisitListScope.pending));
      context.showSnack(
        approve ? context.s.reviewApproved : context.s.reviewRejected,
        kind: approve ? SnackKind.success : SnackKind.info,
      );
    } on ApiException catch (e) {
      if (mounted) context.showSnack(e.localize(context), kind: SnackKind.error);
    } catch (_) {
      if (mounted) {
        context.showSnack(context.s.errActionFailed, kind: SnackKind.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CvSubAppBar(
        title: context.s.reviewTitle,
        eyebrow: context.s.roleManagerTitle,
        topInset: MediaQuery.paddingOf(context).top,
      ),
      body: BlocBuilder<VisitsListBloc, VisitsListState>(
        builder: (context, state) {
          final pending =
              state.items.where((v) => v.isAwaitingApproval).toList();
          // Check failure before empty: otherwise a failed fetch renders
          // "nothing to approve" and the manager closes the app while visits
          // sit waiting. Wrong information is worse than none.
          if (state.status == VisitsListStatus.failure) {
            return ErrorView(
              message: state.error?.localize(context) ?? context.s.errUnknown,
              onRetry: () => context
                  .read<VisitsListBloc>()
                  .add(const VisitsListLoadRequested()),
            );
          }
          if (pending.isEmpty) {
            return EmptyView(
              icon: Symbols.task_alt,
              message: context.s.reviewEmpty,
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              Center(child: _PendingChip(count: pending.length)),
              const SizedBox(height: 14),
              for (final v in pending) ...[
                _ReviewCard(
                  visit: v,
                  busy: _busy,
                  onApprove: () => _decide(v, approve: true),
                  onReject: () async {
                    final reason = await showRejectReasonSheet(context);
                    if (reason == null || !mounted) return;
                    _decide(v, approve: false, reason: reason);
                  },
                ),
                const SizedBox(height: 14),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PendingChip extends StatelessWidget {
  final int count;
  const _PendingChip({required this.count});

  @override
  Widget build(BuildContext context) {
    final x = context.x;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: x.warningContainer,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Symbols.pending, fill: 1, size: 16, color: x.warning),
          const SizedBox(width: 6),
          Text(context.s.reviewPendingCount(count),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: x.onWarningContainer)),
        ],
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
  // There used to be a `_flagged` getter hard-wired to `false` here, plus a
  // full warning banner and a red card border behind it — code that could never
  // run but read as a live feature, which is worse than not having it.
  //
  // Nothing on `dh.visit` stores a geofence verdict and nothing rejects an
  // out-of-range check-in; the 200m ring in `visit_map_card` is drawn and then
  // discarded. The mock-location verdict IS recorded (see
  // `VisitsRepository.hasMockLocationFlag`) and rendered on the visit *detail*
  // page — but this is a list, and the flag lives on the chatter, so showing it
  // per card would cost one round trip per row. The column is the outstanding
  // backend ask that makes it a single query.

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    final timeFmt = AppDate.timeFormat(context);
    final arrival =
        visit.checkInTime != null ? timeFmt.format(context.toUserTime(visit.checkInTime!)) : '—';
    final departure =
        visit.checkOutTime != null ? timeFmt.format(context.toUserTime(visit.checkOutTime!)) : '—';
    final delta = visit.executionDaysDelta;
    final onTimeColor = delta == null
        ? x.textTertiary
        : delta == 0
            ? x.success
            : x.warning;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: x.outlineVariant),
        boxShadow: x.elev1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
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
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: x.avatarGradient,
                              borderRadius: BorderRadius.circular(Radii.btn),
                            ),
                            child: const Icon(Symbols.business,
                                fill: 1, size: 24, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(visit.customerName ?? '#${visit.id}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppType.cardTitle
                                        .copyWith(color: cs.onSurface)),
                                const SizedBox(height: 2),
                                Text(
                                    '${visit.name ?? '#${visit.id}'}${visit.visitTypeName != null ? ' · ${visit.visitTypeName}' : ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: x.textTertiary)),
                              ],
                            ),
                          ),
                          if (visit.visitDuration != null)
                            _DurationChip(duration: visit.visitDuration!),
                          const SizedBox(width: 4),
                          Icon(
                            context.isRtl
                                ? Icons.chevron_left
                                : Icons.chevron_right,
                            size: 18,
                            color: x.textTertiary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Meta strip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainer,
                          borderRadius: BorderRadius.circular(Radii.sm),
                        ),
                        child: Row(
                          children: [
                            Icon(Symbols.person, size: 15, color: x.textTertiary),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(visit.employeeName ?? '-',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: cs.onSurfaceVariant)),
                            ),
                            Icon(Symbols.check_circle,
                                fill: 1, size: 14, color: onTimeColor),
                            const SizedBox(width: 4),
                            Text('$arrival ~ $departure',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: onTimeColor,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ])),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Actions
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: context.s.reviewReject,
                        icon: Symbols.close,
                        bg: cs.errorContainer,
                        fg: cs.error,
                        onTap: busy ? null : onReject,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: _ActionButton(
                        label: context.s.reviewApprove,
                        icon: Symbols.check,
                        bg: x.success,
                        fg: Colors.white,
                        glow: x.glowSuccess,
                        onTap: busy ? null : onApprove,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  final Duration duration;
  const _DurationChip({required this.duration});

  @override
  Widget build(BuildContext context) {
    final x = context.x;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainer,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Symbols.timer, size: 13, color: x.textTertiary),
          const SizedBox(width: 4),
          Text(duration.clock,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.colors.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }
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
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.btn), boxShadow: glow),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.btn),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.btn),
          child: Container(
            height: 48,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, fill: 1, size: 18, color: fg),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.button
                          .copyWith(fontWeight: FontWeight.w800, color: fg)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
