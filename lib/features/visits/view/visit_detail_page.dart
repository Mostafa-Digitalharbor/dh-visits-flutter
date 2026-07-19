import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/service_locator.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_refresh_indicator.dart';
import '../../../shared/widgets/error_view.dart';
import '../bloc/visit_bloc.dart' hide VisitState;
import '../bloc/visit_detail_cubit.dart';
import '../data/models/visit.dart';
import '../data/visits_repository.dart';
import 'visit_action_bar.dart';
import 'visit_attachments_section.dart';
import 'visit_detail_sections.dart';
import 'visit_hero_header.dart';
import 'visit_map_card.dart';

class VisitDetailPage extends StatelessWidget {
  final int visitId;
  final Visit? initial;
  const VisitDetailPage({super.key, required this.visitId, this.initial});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          VisitDetailCubit(repository: sl<VisitsRepository>(), visitId: visitId)
            ..load(),
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
                const SizedBox(height: 14),
                const VisitMockLocationBanner(),
              ],
              const SizedBox(height: 14),
              VisitMapCard(visit: visit),
              const SizedBox(height: 14),
              VisitInfoSection(visit: visit),
              const SizedBox(height: 14),
              VisitApprovalSection(visit: visit),
              if (visit.startDatetime != null) ...[
                const SizedBox(height: 14),
                VisitExecutionSection(visit: visit),
              ],
              if (visit.participants.isNotEmpty) ...[
                const SizedBox(height: 14),
                VisitParticipantsSection(visit: visit),
              ],
              if (visit.attachmentCount > 0) ...[
                const SizedBox(height: 14),
                VisitAttachmentsSection(
                  attachments: widget.state.attachments,
                  error: widget.state.attachmentsError,
                ),
              ],
              const SizedBox(height: 14),
              VisitHistorySection(visit: visit),
            ],
          ),
        ),
        if (busy)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x11000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _MeasureHeight(
            onChange: _onBarHeight,
            child: VisitActionBar(visit: visit),
          ),
        ),
      ],
    );
  }
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

