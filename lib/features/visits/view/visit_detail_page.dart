import 'package:flutter/material.dart';

import '../../../app/design/app_dimens.dart';
import '../../../app/design/responsive.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design/app_colors.dart';
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
import 'visit_action_bar.dart';
import 'visit_attachments_section.dart';
import 'visit_detail_sections.dart';
import 'visit_hero_header.dart';
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
          // `live` is seeded from whatever the caller already knows. A visit
          // opened from the list as `approved` and started from this very page
          // is handled by the reload below, which recreates nothing but does
          // refetch the trail after every action.
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

  String _successMessage(BuildContext context, String action) {
    final s = context.s;
    switch (action) {
      case 'submit':
        return s.wfSubmitted;
      case 'approve':
        return s.wfApproved;
      case 'reject':
        return s.wfRejected;
      case 'start':
        return s.wfStarted;
      case 'end':
        return s.wfEnded;
      case 'reschedule':
        return s.wfRescheduled;
      case 'cancel':
        return s.wfCancelled;
      case 'attachment':
        return s.wfAttachmentAdded;
      case 'participant_approve':
        return s.wfParticipantApproved;
      case 'participant_reject':
        return s.wfParticipantRejected;
      case 'add_participants':
        return s.wfActionAddParticipant;
      case 'start_queued':
      case 'end_queued':
        return s.wfQueuedOffline;
      default:
        return s.commonSave;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VisitDetailCubit, VisitDetailState>(
      listenWhen: (p, c) => c.lastAction != null || c.error != null,
      listener: (context, state) {
        if (state.error != null) {
          context.showSnack(state.error!.localize(context),
              kind: SnackKind.error);
          return;
        }
        final action = state.lastAction;
        if (action == null) return;
        context.showSnack(_successMessage(context, action),
            kind: SnackKind.success);

        // Every workflow action changes the visit's state, so the list this
        // page sits on top of is now stale. It is app-scoped and caches its
        // rows, so without this it keeps serving the pre-action state — after
        // ending a visit the user was popped straight back onto a list still
        // labelling it "Approved", with pull-to-refresh not helping because the
        // terminal actions never asked for a reload at all.
        //
        // Attachment uploads don't alter the list's rendering, so they're the
        // one action that doesn't need it. (This compared against
        // `'upload_attachment'`, which the cubit never emits — the action is
        // named `'attachment'` — so every upload refetched the whole list.)
        if (action != 'attachment') {
          context.read<VisitsListBloc>().add(const VisitsListLoadRequested());
        }

        // Start and End each write a point onto the trail server-side (the
        // first and the last), so the drawn path is stale the moment either
        // lands. Everything else leaves it untouched.
        if (action == 'start' ||
            action == 'end' ||
            action == 'start_queued' ||
            action == 'end_queued') {
          context.read<VisitTrailCubit>().load(silent: true);
        }

        // Keep the persistent bar in sync with Start/End.
        if (action == 'start') {
          context.read<VisitBloc>().add(const VisitResumeRequested());
        } else if (action == 'end') {
          context.read<VisitBloc>().add(const VisitCleared());
          Navigator.of(context).maybePop();
        } else if (action == 'cancel') {
          Navigator.of(context).maybePop();
        }
      },
      builder: (context, state) {
        final visit = state.visit ?? initial;
        return Scaffold(
          appBar: AppBar(title: Text(visit?.name ?? context.s.wfDetailTitle)),
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

  void _onBarHeight(double h) {
    if ((h - _barHeight).abs() < 0.5) return;
    // Defer to avoid mutating state during the layout/paint phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _barHeight = h);
    });
  }

  @override
  Widget build(BuildContext context) {
    final visit = widget.visit;
    final busy = widget.state.status == VisitDetailStatus.acting;
    return Stack(
      children: [
        AppRefreshIndicator(
          onRefresh: () => context.read<VisitDetailCubit>().load(),
          child: ListView(
            // Extra breathing room below the last card so it can scroll fully
            // clear of the pinned action bar.
            padding: EdgeInsets.fromLTRB(16, 16, 16, _barHeight + 24),
            children: [
              VisitHeroHeader(visit: visit),
              // Above everything else on purpose: a manager deciding whether to
              // approve must meet this before the map makes the visit look
              // legitimate.
              if (widget.state.mockFlagged) ...[
                context.gapH(Insets.x3h),
                const VisitMockLocationBanner(),
              ],
              context.gapH(Insets.x3h),
              BlocBuilder<VisitTrailCubit, VisitTrailState>(
                builder: (context, trail) => VisitMapCard(
                  visit: visit,
                  trail: trail.track,
                  onOpenTrail: () => _openTrail(context, visit),
                ),
              ),
              context.gapH(Insets.x3h),
              VisitInfoSection(visit: visit),
              context.gapH(Insets.x3h),
              VisitApprovalSection(visit: visit),
              if (visit.startDatetime != null) ...[
                context.gapH(Insets.x3h),
                VisitExecutionSection(visit: visit),
                context.gapH(Insets.x3h),
                VisitTrailSection(
                  visit: visit,
                  onOpenTrail: () => _openTrail(context, visit),
                ),
              ],
              if (visit.participants.isNotEmpty) ...[
                context.gapH(Insets.x3h),
                VisitParticipantsSection(visit: visit),
              ],
              if (visit.attachmentCount > 0) ...[
                context.gapH(Insets.x3h),
                VisitAttachmentsSection(
                  attachments: widget.state.attachments,
                  error: widget.state.attachmentsError,
                ),
              ],
              context.gapH(Insets.x3h),
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
        Positioned(
          left: 0,
          right: 0,
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
          final box = context.findRenderObject() as RenderBox?;
          if (box != null && box.hasSize) onChange(box.size.height);
        });
        return child;
      },
    );
  }
}

