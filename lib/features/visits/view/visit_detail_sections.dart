import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design/app_colors.dart';
import '../../../app/design/app_dimens.dart';
import '../../../app/routes.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/duration_format.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/data/models/user.dart';
import '../data/models/visit.dart';
import '../data/models/visit_participant.dart';
import '../bloc/visit_detail_cubit.dart';
import 'action_sheets.dart';
import 'visit_detail_row.dart';
import 'visit_labels.dart';
import 'visit_section.dart';

/// Visit details: customer, type, schedule, purpose, planned location.
class VisitInfoSection extends StatelessWidget {
  final Visit visit;
  const VisitInfoSection({super.key, required this.visit});

  @override
  Widget build(BuildContext context) {
    final df = AppDate.weekdayDateTimeFormat(context);
    final rows = <Widget>[
      if (visit.partnerName != null && visit.partnerName!.isNotEmpty)
        VisitDetailRow(
          icon: Icons.storefront_outlined,
          label: context.s.wfFieldCustomer,
          value: visit.partnerName!,
          onTap: visit.customerId != null
              ? () => context.push(
                  AppRoutes.customerDetail(visit.customerId!))
              : null,
        ),
      if (visit.linkedRecordName != null)
        VisitDetailRow(
          icon: visit.isOpportunity
              ? Icons.emoji_events_outlined
              : Icons.folder_open_outlined,
          label: visit.isOpportunity
              ? context.s.wfFieldOpportunity
              : context.s.wfFieldProject,
          value: visit.linkedRecordName!,
        ),
      if (visit.scheduledDatetime != null)
        VisitDetailRow(
          icon: Icons.schedule,
          label: context.s.wfFieldSchedule,
          value: df.format(visit.scheduledDatetime!.toLocal()),
        ),
      if (visit.purpose != null && visit.purpose!.isNotEmpty)
        VisitDetailRow(
          icon: Icons.flag_outlined,
          label: context.s.wfFieldPurpose,
          value: visit.purpose!,
        ),
      if (visit.location != null && visit.location!.isNotEmpty)
        VisitDetailRow(
          icon: Icons.place_outlined,
          label: context.s.wfFieldLocation,
          value: visit.location!,
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return VisitSection(
      icon: Icons.info_outline_rounded,
      title: context.s.wfSectionVisitInfo,
      rows: rows,
    );
  }
}

/// The responsible employee + approval chain.
class VisitApprovalSection extends StatelessWidget {
  final Visit visit;
  const VisitApprovalSection({super.key, required this.visit});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      if (visit.employeeName != null)
        VisitDetailRow(
          icon: Icons.person_outline,
          label: context.s.wfFieldResponsible,
          value: visit.employeeName!,
        ),
      if (visit.directManagerName != null)
        VisitDetailRow(
          icon: Icons.badge_outlined,
          label: context.s.wfFieldDirectManager,
          value: visit.directManagerName!,
        ),
      if (visit.higherManagerName != null)
        VisitDetailRow(
          icon: Icons.badge_outlined,
          label: context.s.wfFieldHigherManager,
          value: visit.higherManagerName!,
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return VisitSection(
      icon: Icons.groups_outlined,
      title: context.s.wfSectionApproval,
      rows: rows,
    );
  }
}

/// Shown when a mock-location (fake-GPS) verdict was recorded against this
/// visit at check-in or check-out.
///
/// The verdict itself lives on the Odoo chatter rather than a field on
/// `dh.visit` — see `VisitsRepository.hasMockLocationFlag`. Surfacing it here
/// is the point of the whole mechanism: detection that only a developer can
/// see in Sentry is not a control, it is a log line.
class VisitMockLocationBanner extends StatelessWidget {
  const VisitMockLocationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: cs.error.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.gpp_bad_outlined, color: cs.error, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.s.wfMockFlagBannerTitle,
                  style: context.text.titleSmall?.copyWith(
                    color: cs.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.s.wfMockFlagBannerBody,
                  style: context.text.bodySmall
                      ?.copyWith(color: cs.onErrorContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Field execution: start/end (time + GPS + open-in-maps), duration, outcome.
class VisitExecutionSection extends StatelessWidget {
  final Visit visit;
  const VisitExecutionSection({super.key, required this.visit});

  /// Visits shorter than this read as suspiciously brief and are flagged.
  static const _shortVisit = Duration(minutes: 2);

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final df = AppDate.weekdayDateTimeFormat(context);
    final dur = visit.executionDuration;
    final isShort = dur != null && dur < _shortVisit;

    final rows = <Widget>[
      if (visit.startDatetime != null)
        VisitDetailRow(
          icon: Icons.play_circle_outline,
          iconColor: AppColors.green,
          label: context.s.wfStartedLabel,
          value: df.format(visit.startDatetime!.toLocal()),
        ),
      if (visit.hasStartLocation || visit.startLocation != null)
        VisitDetailRow(
          icon: Icons.my_location_outlined,
          iconColor: AppColors.green,
          label: context.s.wfFieldStartLocation,
          value: visit.startLocation ??
              '${visit.startLat!.toStringAsFixed(5)}, ${visit.startLng!.toStringAsFixed(5)}',
          trailing: visit.hasStartLocation
              ? VisitMapsPill(
                  latitude: visit.startLat!,
                  longitude: visit.startLng!,
                  label: visit.startLocation,
                )
              : null,
        ),
      if (visit.endDatetime != null)
        VisitDetailRow(
          icon: Icons.stop_circle_outlined,
          iconColor: Colors.deepOrange,
          label: context.s.wfEndedLabel,
          value: df.format(visit.endDatetime!.toLocal()),
        ),
      if (visit.hasEndLocation || visit.endLocation != null)
        VisitDetailRow(
          icon: Icons.location_on_outlined,
          iconColor: Colors.deepOrange,
          label: context.s.wfFieldEndLocation,
          value: visit.endLocation ??
              '${visit.endLat!.toStringAsFixed(5)}, ${visit.endLng!.toStringAsFixed(5)}',
          trailing: visit.hasEndLocation
              ? VisitMapsPill(
                  latitude: visit.endLat!,
                  longitude: visit.endLng!,
                  label: visit.endLocation,
                )
              : null,
        ),
      if (dur != null)
        VisitDetailRow(
          icon: Icons.timelapse,
          iconColor: isShort ? AppColors.amber : cs.primary,
          label: context.s.wfDurationLabel,
          value: dur.localized(context),
          valueColor: isShort ? AppColors.amber : null,
          trailing: isShort
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Text(
                    context.s.wfShortVisitHint,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.amber,
                    ),
                  ),
                )
              : null,
        ),
      if (visit.outcome != null && visit.outcome!.isNotEmpty)
        VisitDetailRow(
          icon: Icons.task_alt,
          label: context.s.wfFieldOutcome,
          value: visit.outcome!,
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return VisitSection(
      icon: Icons.route_outlined,
      title: context.s.wfSectionExecution,
      rows: rows,
    );
  }
}

class VisitParticipantsSection extends StatelessWidget {
  final Visit visit;
  const VisitParticipantsSection({super.key, required this.visit});

  @override
  Widget build(BuildContext context) {
    final me = context.read<AuthBloc>().state.user;
    return VisitSection(
      icon: Icons.groups_2_outlined,
      title: context.s.wfParticipantsSection,
      rows: [
        for (final p in visit.participants)
          _ParticipantTile(visit: visit, participant: p, me: me),
      ],
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
    // The current backend keeps a visit with pending participants in
    // `submitted`; older builds used `waiting_participant_manager_approval`.
    if (visit.state != VisitState.submitted &&
        visit.state != VisitState.waitingParticipantManagerApproval) {
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Radii.tile),
            ),
            child: Icon(Icons.person_outline, size: 19, color: tone),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  participant.employeeName ?? '#${participant.employeeId}',
                  style: context.text.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  participantStateLabel(context, participant.approvalState),
                  style: TextStyle(
                    color: tone,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          if (_canAct)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.check_circle, color: Colors.green.shade700),
                  tooltip: context.s.wfApproveParticipant,
                  onPressed: () => context
                      .read<VisitDetailCubit>()
                      .approveParticipant(participant.id),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
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
            ),
        ],
      ),
    );
  }
}

class VisitHistorySection extends StatelessWidget {
  final Visit visit;
  const VisitHistorySection({super.key, required this.visit});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final df = AppDate.dateTimeFormat(context);
    final rows = <Widget>[
      if (visit.submittedDate != null)
        VisitDetailRow(
          icon: Icons.send_outlined,
          label: context.s.wfSubmittedOn,
          value: df.format(visit.submittedDate!.toLocal()),
        ),
      if (visit.isEscalated && visit.escalationDate != null)
        VisitDetailRow(
          icon: Icons.priority_high_rounded,
          iconColor: cs.error,
          label: context.s.wfEscalatedBadge,
          value: df.format(visit.escalationDate!.toLocal()),
        ),
      if (visit.approvedByName != null)
        VisitDetailRow(
          icon: Icons.check_circle_outline,
          iconColor: AppColors.green,
          label: context.s.wfApprovedByOn,
          value: '${visit.approvedByName}'
              '${visit.approvedDate != null ? ' · ${df.format(visit.approvedDate!.toLocal())}' : ''}',
        ),
      if (visit.rejectedByName != null)
        VisitDetailRow(
          icon: Icons.cancel_outlined,
          iconColor: cs.error,
          label: context.s.wfRejectedByOn,
          value: '${visit.rejectedByName}'
              '${visit.rejectedDate != null ? ' · ${df.format(visit.rejectedDate!.toLocal())}' : ''}',
        ),
      if (visit.rejectReason != null)
        VisitDetailRow(
          icon: Icons.notes_outlined,
          iconColor: cs.error,
          label: context.s.wfReason,
          value: visit.rejectReason!,
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return VisitSection(
      icon: Icons.history_rounded,
      title: context.s.wfApprovalHistory,
      rows: rows,
    );
  }
}

