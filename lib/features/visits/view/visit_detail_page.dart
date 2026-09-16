import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design/app_colors.dart';
import '../../../app/design/app_dimens.dart';
import '../../../app/design/responsive.dart';
import '../../../app/routes.dart';
import '../../../core/di/service_locator.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_refresh_indicator.dart';
import '../../../shared/widgets/error_view.dart';
import '../bloc/visit_bloc.dart' hide VisitState;
import '../bloc/visit_detail_cubit.dart';
import '../bloc/visit_trail_cubit.dart';
import '../bloc/visits_list_bloc.dart';
import '../data/models/visit.dart';
import '../data/visit_trail_tracker.dart';
import '../data/visits_repository.dart';
import '../domain/visit_action.dart';
import 'visit_action_bar.dart';
import 'visit_attachments_section.dart';
import 'visit_detail_sections.dart';
import 'visit_hero_header.dart';
import 'visit_labels.dart';
import 'visit_map_card.dart';
import 'visit_trail_section.dart';

class VisitDetailPage extends StatelessWidget {
  final int visitId;
  final Visit? initial;
  const VisitDetailPage({super.key, required this.visitId, this.initial});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => VisitDetailCubit(
            repository: sl<VisitsRepository>(),
            visitId: visitId,
          )..load(),
        ),
        BlocProvider(
          // `live` is seeded from whatever the caller already knows; the body
          // corrects it once the visit has loaded.
          create: (_) => VisitTrailCubit(
            repository: sl<VisitsRepository>(),
            tracker: slMaybe<VisitTrailTracker>(),
            visitId: visitId,
            live: initial?.isTrackingLive ?? false,
          )..load(),
        ),
      ],
      child: _VisitDetailView(initial: initial),
    );
  }
}

class _VisitDetailView extends StatelessWidget {
  final Visit? initial;
  const _VisitDetailView({this.initial});

  static String _successMessage(BuildContext context, VisitActionOutcome o) {
    final s = context.s;
    if (o.queued) return s.wfQueuedOffline;
    return switch (o.action) {
      VisitAction.submit => s.wfSubmitted,
      VisitAction.approve => s.wfApproved,
      VisitAction.reject => s.wfRejected,
      VisitAction.cancel => s.wfCancelled,
      VisitAction.reschedule => s.wfRescheduled,
      VisitAction.start => s.wfStarted,
      VisitAction.end => s.wfEnded,
      VisitAction.attachment => s.wfAttachmentAdded,
      VisitAction.addParticipants => s.wfParticipantsAdded,
      VisitAction.participantApprove => s.wfParticipantApproved,
      VisitAction.participantReject => s.wfParticipantRejected,
    };
  }

  void _onOutcome(
    BuildContext context,
    VisitActionOutcome outcome,
    Visit? visit,
  ) {
    context.showSnack(
      _successMessage(context, outcome),
      kind: SnackKind.success,
    );
    final action = outcome.action;

    // Every workflow action changes the visit's state, so the list this page
    // sits on top of is now stale. It is app-scoped and caches its rows, so
    // without this it keeps serving the pre-action state. Attachment uploads
    // don't alter the list's rendering, so they're the one action that
    // doesn't need it.
    if (action != VisitAction.attachment) {
      context.read<VisitsListBloc>().add(const VisitsListLoadRequested());
    }

    // Start and End each write a point onto the trail server-side (the first
    // and the last), so the drawn path is stale the moment either lands.
    if (action.isQueueable) {
      context.read<VisitTrailCubit>().load(silent: true);
    }

    // Keep the persistent bar in sync with Start/End — including when the
    // action only reached the offline queue: the rep is on the visit either
    // way, and asking the server would fail offline.
    switch (action) {
      case VisitAction.start:
        if (visit != null) context.read<VisitBloc>().add(VisitStarted(visit));
      case VisitAction.end:
        context.read<VisitBloc>().add(const VisitCleared());
        Navigator.of(context).maybePop();
      case VisitAction.cancel:
        Navigator.of(context).maybePop();
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VisitDetailCubit, VisitDetailState>(
      listenWhen: (p, c) => c.lastAction != null || c.error != null,
      listener: (context, state) {
        final error = state.error;
        if (error != null) {
          context.showSnack(error.localize(context), kind: SnackKind.error);
          return;
        }
        final outcome = state.lastAction;
        if (outcome != null) _onOutcome(context, outcome, state.visit);
      },
      builder: (context, state) {
        final visit = state.visit ?? initial;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              visit?.displayReference(context) ?? context.s.wfDetailTitle,
            ),
          ),
          body: _body(context, state, visit),
        );
      },
    );
  }

  Widget _body(BuildContext context, VisitDetailState state, Visit? visit) {
    if (visit == null) {
      if (state.status == VisitDetailStatus.error) {
        return ErrorView(
          message: state.error?.localize(context) ?? context.s.errUnknown,
          onRetry: () => context.read<VisitDetailCubit>().load(),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    return _VisitDetailBody(state: state, visit: visit);
  }
}

/// Hosts the scrollable detail + the bottom action bar. Keeps the action-bar
/// height in state so the list can reserve exactly enough bottom padding for
/// its last card to scroll clear of the (variable-height) pinned buttons.
class _VisitDetailBody extends StatefulWidget {
  final VisitDetailState state;
  final Visit visit;
  const _VisitDetailBody({required this.state, required this.visit});

  @override
  State<_VisitDetailBody> createState() => _VisitDetailBodyState();
}

class _VisitDetailBodyState extends State<_VisitDetailBody> {
  double _barHeight = 0;

  /// Below this change a re-measured bar is the same bar (sub-pixel layout
  /// noise), and rebuilding the list for it would loop.
  static const double _heightTolerance = 0.5;

  // The trail polls only while the visit runs. The page seeds that from what
  // the caller knew, which is nothing for a visit opened from a notification,
  // and a visit can start or end while it is open.
  @override
  void initState() {
    super.initState();
    context.read<VisitTrailCubit>().setLive(widget.visit.isTrackingLive);
  }

  @override
  void didUpdateWidget(_VisitDetailBody old) {
    super.didUpdateWidget(old);
    if (old.visit.isTrackingLive != widget.visit.isTrackingLive) {
      context.read<VisitTrailCubit>().setLive(widget.visit.isTrackingLive);
    }
  }

  void _onBarHeight(double h) {
    if ((h - _barHeight).abs() < _heightTolerance) return;
    // Defer to avoid mutating state during the layout/paint phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _barHeight = h);
    });
  }

  @override
  Widget build(BuildContext context) {
    final visit = widget.visit;
    final state = widget.state;
    final busy = state.status == VisitDetailStatus.acting;
    final gap = context.gapH(Insets.x3h);
    final edge = context.r(Insets.screen);
    return Stack(
      children: [
        AppRefreshIndicator(
          onRefresh: () => context.read<VisitDetailCubit>().load(),
          child: ListView(
            // Extra breathing room below the last card so it can scroll fully
            // clear of the pinned action bar.
            padding: EdgeInsetsDirectional.fromSTEB(
              edge,
              edge,
              edge,
              _barHeight + context.r(Insets.x6),
            ),
            children: [
              VisitHeroHeader(visit: visit),
              // Above everything else on purpose: a manager deciding whether to
              // approve must meet this before the map makes the visit look
              // legitimate.
              if (state.mockFlagged) ...[gap, const VisitMockLocationBanner()],
              gap,
              BlocBuilder<VisitTrailCubit, VisitTrailState>(
                builder: (context, trail) => VisitMapCard(
                  visit: visit,
                  trail: trail.track,
                  onOpenTrail: () => _openTrail(context, visit),
                ),
              ),
              gap,
              VisitInfoSection(visit: visit),
              gap,
              VisitApprovalSection(visit: visit),
              if (visit.startDatetime != null) ...[
                gap,
                VisitExecutionSection(visit: visit),
                gap,
                VisitTrailSection(
                  visit: visit,
                  onOpenTrail: () => _openTrail(context, visit),
                ),
              ],
              if (visit.participants.isNotEmpty) ...[
                gap,
                VisitParticipantsSection(visit: visit),
              ],
              // Shown whenever there is something to say: the count comes from
              // the rich read only, so a visit loaded through the slim REST
              // fallback reports 0 even when its files loaded fine.
              if (visit.attachmentCount > 0 ||
                  state.attachments.isNotEmpty ||
                  state.attachmentsError != null) ...[
                gap,
                VisitAttachmentsSection(
                  attachments: state.attachments,
                  error: state.attachmentsError,
                ),
              ],
              gap,
              VisitHistorySection(visit: visit),
            ],
          ),
        ),
        if (busy)
          const Positioned.fill(
            child: ColoredBox(
              color: AppColors.shadowSoft,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        PositionedDirectional(
          start: 0,
          end: 0,
          bottom: 0,
          // The bar sits ABOVE the busy scrim in the stack, so the scrim alone
          // does not stop taps reaching it. Without this guard a double-tap on
          // Approve fires the workflow call twice; the second hits an
          // already-approved visit, comes back a UserError, and lands after the
          // first — so a successful approval ends up showing a red error.
          child: IgnorePointer(
            ignoring: busy,
            child: _MeasureHeight(
              onChange: _onBarHeight,
              child: VisitActionBar(visit: visit),
            ),
          ),
        ),
      ],
    );
  }
}

/// Opens the full-screen trail, handing the visit over so the page knows
/// whether it is watching a live route or reading a finished one.
void _openTrail(BuildContext context, Visit visit) {
  context.push(AppRoutes.visitTrail(visit.id), extra: visit);
}

/// Reports its child's rendered height via [onChange] after each layout.
class _MeasureHeight extends StatelessWidget {
  final Widget child;
  final ValueChanged<double> onChange;
  const _MeasureHeight({required this.child, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          final box = context.findRenderObject() as RenderBox?;
          if (box != null && box.hasSize) onChange(box.size.height);
        });
        return child;
      },
    );
  }
}
