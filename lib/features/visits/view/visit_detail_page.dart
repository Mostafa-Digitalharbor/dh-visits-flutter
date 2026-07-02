import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/location/location_service.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/error_view.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/data/models/user.dart';
import '../bloc/visit_bloc.dart' hide VisitState;
import '../bloc/visit_detail_cubit.dart';
import '../data/models/visit.dart';
import '../data/models/visit_participant.dart';
import '../data/visits_repository.dart';
import 'action_sheets.dart';
import 'visit_labels.dart';

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
    final busy = state.status == VisitDetailStatus.acting;
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => context.read<VisitDetailCubit>().load(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Header(visit: visit),
              const SizedBox(height: 16),
              _InfoSection(visit: visit),
              if (visit.participants.isNotEmpty) ...[
                const SizedBox(height: 16),
                _ParticipantsSection(visit: visit),
              ],
              const SizedBox(height: 16),
              _HistorySection(visit: visit),
              const SizedBox(height: 100),
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
          child: _ActionBar(visit: visit),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final Visit visit;
  const _Header({required this.visit});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    visit.partnerName ?? '#${visit.id}',
                    style: context.text.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                VisitStateBadge(visit.state),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${visitTypeLabel(context, visit.visitType)}'
              '${visit.linkedRecordName != null ? ' · ${visit.linkedRecordName}' : ''}',
              style: context.text.bodyMedium
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final Visit visit;
  const _InfoSection({required this.visit});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEE, MMM d • HH:mm');
    final rows = <(IconData, String, String?)>[
      (Icons.schedule, context.s.wfFieldSchedule,
          visit.scheduledDatetime != null
              ? df.format(visit.scheduledDatetime!.toLocal())
              : null),
      (Icons.flag_outlined, context.s.wfFieldPurpose, visit.purpose),
      (Icons.place_outlined, context.s.wfFieldLocation, visit.location),
      (Icons.person_outline, context.s.wfFieldResponsible, visit.employeeName),
      (Icons.badge_outlined, context.s.wfFieldDirectManager,
          visit.directManagerName),
      if (visit.outcome != null)
        (Icons.task_alt, context.s.wfFieldOutcome, visit.outcome),
      if (visit.startDatetime != null)
        (Icons.play_circle_outline, context.s.wfStartedLabel,
            df.format(visit.startDatetime!.toLocal())),
      if (visit.endDatetime != null)
        (Icons.stop_circle_outlined, context.s.wfEndedLabel,
            df.format(visit.endDatetime!.toLocal())),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            for (final r in rows)
              if (r.$3 != null && r.$3!.isNotEmpty)
                ListTile(
                  dense: true,
                  leading: Icon(r.$1, size: 20),
                  title: Text(r.$2, style: context.text.labelMedium),
                  subtitle: Text(r.$3!, style: context.text.bodyMedium),
                ),
          ],
        ),
      ),
    );
  }
}

class _ParticipantsSection extends StatelessWidget {
  final Visit visit;
  const _ParticipantsSection({required this.visit});

  @override
  Widget build(BuildContext context) {
    final me = context.read<AuthBloc>().state.user;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.s.wfParticipantsSection,
                style: context.text.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            for (final p in visit.participants)
              _ParticipantTile(visit: visit, participant: p, me: me),
          ],
        ),
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  final Visit visit;
  final VisitParticipant participant;
  final AuthUser? me;
  const _ParticipantTile({
    required this.visit,
    required this.participant,
    required this.me,
  });

  bool get _canAct {
    if (participant.approvalState != ParticipantApprovalState.pending) {
      return false;
    }
    if (visit.state != VisitState.waitingParticipantManagerApproval) {
      return false;
    }
    final u = me;
    if (u == null) return false;
    final isTheirManager =
        u.employeeId != null && u.employeeId == participant.managerId;
    return isTheirManager || u.canApproveVisits;
  }

  @override
  Widget build(BuildContext context) {
    final tone = switch (participant.approvalState) {
      ParticipantApprovalState.approved => Colors.green.shade700,
      ParticipantApprovalState.rejected => context.colors.error,
      _ => Colors.orange.shade700,
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.person_outline),
      title: Text(participant.employeeName ?? '#${participant.employeeId}'),
      subtitle: Text(
        participantStateLabel(context, participant.approvalState),
        style: TextStyle(color: tone, fontWeight: FontWeight.w600),
      ),
      trailing: _canAct
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.check_circle, color: Colors.green.shade700),
                  tooltip: context.s.wfApproveParticipant,
                  onPressed: () => context
                      .read<VisitDetailCubit>()
                      .approveParticipant(participant.id),
                ),
                IconButton(
                  icon: Icon(Icons.cancel, color: context.colors.error),
                  tooltip: context.s.wfRejectParticipant,
                  onPressed: () async {
                    final reason = await showRejectReasonSheet(context);
                    if (reason == null || !context.mounted) return;
                    context
                        .read<VisitDetailCubit>()
                        .rejectParticipant(participant.id, reason);
                  },
                ),
              ],
            )
          : null,
    );
  }
}

class _HistorySection extends StatelessWidget {
  final Visit visit;
  const _HistorySection({required this.visit});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MMM d, HH:mm');
    final entries = <(String, String)>[
      if (visit.submittedDate != null)
        (context.s.wfSubmittedOn, df.format(visit.submittedDate!.toLocal())),
      if (visit.approvedByName != null)
        (
          context.s.wfApprovedByOn,
          '${visit.approvedByName}'
              '${visit.approvedDate != null ? ' · ${df.format(visit.approvedDate!.toLocal())}' : ''}'
        ),
      if (visit.rejectedByName != null)
        (
          context.s.wfRejectedByOn,
          '${visit.rejectedByName}'
              '${visit.rejectedDate != null ? ' · ${df.format(visit.rejectedDate!.toLocal())}' : ''}'
        ),
      if (visit.rejectReason != null)
        (context.s.wfReason, visit.rejectReason!),
    ];
    if (entries.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.s.wfApprovalHistory,
                style: context.text.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${e.$1}: ',
                        style: context.text.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Expanded(child: Text(e.$2, style: context.text.bodyMedium)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Role- and state-aware action buttons pinned to the bottom.
class _ActionBar extends StatelessWidget {
  final Visit visit;
  const _ActionBar({required this.visit});

  Future<(double, double)?> _location(BuildContext context) async {
    final loc = sl<LocationService>();
    final ok = await loc.ensurePermission();
    if (!ok) return null;
    final pos = await loc.getCurrent();
    return (pos.latitude, pos.longitude);
  }

  Future<void> _pickAndUpload(
      BuildContext context, VisitDetailCubit cubit) async {
    final result = await FilePicker.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;
    await cubit.uploadAttachment(filename: f.name, dataB64: base64Encode(bytes));
  }

  @override
  Widget build(BuildContext context) {
    final me = context.read<AuthBloc>().state.user;
    final cubit = context.read<VisitDetailCubit>();
    final isOwner =
        me?.employeeId != null && me!.employeeId == visit.employeeId;
    final canApprove =
        (me?.canApproveVisits ?? false) && !isOwner && visit.isAwaitingApproval;

    final buttons = <Widget>[];

    if (isOwner && visit.canSubmit) {
      buttons.add(AppButton(
        label: context.s.wfActionSubmit,
        icon: Icons.send_outlined,
        onPressed: cubit.submit,
      ));
    }
    if (canApprove) {
      buttons.add(AppButton(
        label: context.s.wfActionApprove,
        icon: Icons.check_circle_outline,
        onPressed: cubit.approve,
      ));
      buttons.add(AppButton.destructive(
        label: context.s.wfActionReject,
        onPressed: () async {
          final reason = await showRejectReasonSheet(context);
          if (reason == null || !context.mounted) return;
          cubit.reject(reason);
        },
      ));
    }
    if (isOwner && visit.canStart) {
      buttons.add(AppButton(
        label: context.s.wfActionStart,
        icon: Icons.play_arrow_rounded,
        onPressed: () async {
          final ll = await _location(context);
          if (!context.mounted) return;
          cubit.start(latitude: ll?.$1, longitude: ll?.$2);
        },
      ));
    }
    if (isOwner && visit.canEnd) {
      buttons.add(AppButton(
        label: context.s.wfActionEnd,
        icon: Icons.stop_circle_outlined,
        onPressed: () async {
          final outcome =
              await showEndVisitSheet(context, initial: visit.outcome);
          if (outcome == null || !context.mounted) return;
          final ll = await _location(context);
          if (!context.mounted) return;
          cubit.end(outcome: outcome, latitude: ll?.$1, longitude: ll?.$2);
        },
      ));
    }
    if (isOwner && (visit.isApproved || visit.isAwaitingApproval)) {
      buttons.add(AppButton.secondary(
        label: context.s.wfActionReschedule,
        icon: Icons.event_repeat,
        onPressed: () async {
          final r = await showRescheduleSheet(
            context,
            initialSchedule: visit.scheduledDatetime,
            initialPurpose: visit.purpose,
            initialLocation: visit.location,
          );
          if (r == null || !context.mounted) return;
          cubit.reschedule(
            scheduledDatetime: r.scheduled,
            purpose: r.purpose,
            location: r.location,
          );
        },
      ));
    }
    if ((isOwner || (me?.canApproveVisits ?? false)) &&
        !visit.isCancelled &&
        !visit.isRejected) {
      buttons.add(AppButton.secondary(
        label: visit.attachmentCount > 0
            ? '${context.s.wfActionAddAttachment} (${visit.attachmentCount})'
            : context.s.wfActionAddAttachment,
        icon: Icons.attach_file,
        onPressed: () => _pickAndUpload(context, cubit),
      ));
    }
    if ((isOwner || (me?.canApproveVisits ?? false)) &&
        !visit.isDone &&
        !visit.isCancelled &&
        !visit.isRejected &&
        visit.state != VisitState.inProgress) {
      buttons.add(AppButton.secondary(
        label: context.s.wfActionCancel,
        icon: Icons.block,
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(ctx.s.wfConfirmCancelTitle),
              content: Text(ctx.s.wfConfirmCancelMessage),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(ctx.s.commonNo)),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(ctx.s.commonYes)),
              ],
            ),
          );
          if (ok != true || !context.mounted) return;
          cubit.cancel();
        },
      ));
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final b in buttons)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: b,
              ),
          ],
        ),
      ),
    );
  }
}
