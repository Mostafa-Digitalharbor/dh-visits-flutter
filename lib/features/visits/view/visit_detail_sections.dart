import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design/app_dimens.dart';
import '../../../app/design/app_typography.dart';
import '../../../app/design/responsive.dart';
import '../../../app/routes.dart';
import '../../../core/location/location_describe.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/duration_format.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/data/models/user.dart';
import '../bloc/visit_detail_cubit.dart';
import '../data/models/visit.dart';
import '../data/models/visit_participant.dart';
import '../visit_constants.dart';
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
    final customer = visit.partnerName;
    final customerId = visit.customerId;
    final linked = visit.linkedRecordName;
    final scheduled = visit.scheduledDatetime;
    final purpose = visit.purpose;
    final location = visit.location;
    final rows = <Widget>[
      if (customer != null)
        VisitDetailRow(
          icon: Icons.storefront_outlined,
          label: context.s.wfFieldCustomer,
          value: customer,
          onTap: customerId != null
              ? () => context.push(AppRoutes.customerDetail(customerId))
              : null,
        ),
      if (linked != null)
        VisitDetailRow(
          icon: visit.isOpportunity
              ? Icons.emoji_events_outlined
              : Icons.folder_open_outlined,
          label: visit.isOpportunity
              ? context.s.wfFieldOpportunity
              : context.s.wfFieldProject,
          value: linked,
        ),
      if (scheduled != null)
        VisitDetailRow(
          icon: Icons.schedule,
          label: context.s.wfFieldSchedule,
          value: df.format(scheduled.toLocal()),
        ),
      if (purpose != null)
        VisitDetailRow(
          icon: Icons.flag_outlined,
          label: context.s.wfFieldPurpose,
          value: purpose,
        ),
      if (location != null)
        VisitDetailRow(
          icon: Icons.place_outlined,
          label: context.s.wfFieldLocation,
          value: location,
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
    final employee = visit.employeeName;
    final direct = visit.directManagerName;
    final higher = visit.higherManagerName;
    final rows = <Widget>[
      if (employee != null)
        VisitDetailRow(
          icon: Icons.person_outline,
          label: context.s.wfFieldResponsible,
          value: employee,
        ),
      if (direct != null)
        VisitDetailRow(
          icon: Icons.badge_outlined,
          label: context.s.wfFieldDirectManager,
          value: direct,
        ),
      if (higher != null)
        VisitDetailRow(
          icon: Icons.badge_outlined,
          label: context.s.wfFieldHigherManager,
          value: higher,
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
      padding: context.padSym(h: Insets.x3h, v: Insets.x3),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: cs.error.withValues(alpha: Alphas.disabled)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.gpp_bad_outlined,
            color: cs.error,
            size: context.r(IconSz.tile),
          ),
          context.gapW(Insets.x2h),
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
                context.gapH(Insets.x1),
                Text(
                  context.s.wfMockFlagBannerBody,
                  style: context.text.bodySmall?.copyWith(
                    color: cs.onErrorContainer,
                  ),
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

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final df = AppDate.weekdayDateTimeFormat(context);
    final dur = visit.executionDuration;
    final isShort = dur != null && dur < VisitConstants.shortVisit;
    final started = visit.startDatetime;
    final ended = visit.endDatetime;
    final outcome = visit.outcome;
    final startTone = context.visitSuccess;
    final endTone = context.visitWarning;

    final rows = <Widget>[
      if (started != null)
        VisitDetailRow(
          icon: Icons.play_circle_outline,
          iconColor: startTone,
          label: context.s.wfStartedLabel,
          value: df.format(started.toLocal()),
        ),
      if (_placeRow(
            context,
            icon: Icons.my_location_outlined,
            tone: startTone,
            label: context.s.wfFieldStartLocation,
            latitude: visit.startLat,
            longitude: visit.startLng,
            place: visit.startLocation,
          )
          case final row?)
        row,
      if (ended != null)
        VisitDetailRow(
          icon: Icons.stop_circle_outlined,
          iconColor: endTone,
          label: context.s.wfEndedLabel,
          value: df.format(ended.toLocal()),
        ),
      if (_placeRow(
            context,
            icon: Icons.location_on_outlined,
            tone: endTone,
            label: context.s.wfFieldEndLocation,
            latitude: visit.endLat,
            longitude: visit.endLng,
            place: visit.endLocation,
          )
          case final row?)
        row,
      if (dur != null)
        VisitDetailRow(
          icon: Icons.timelapse,
          iconColor: isShort ? context.visitWarning : cs.primary,
          label: context.s.wfDurationLabel,
          value: dur.localized(context),
          valueColor: isShort ? context.visitWarning : null,
          trailing: isShort
              ? Flexible(
                  child: TonePill(
                    label: context.s.wfShortVisitHint,
                    color: context.visitWarning,
                    fontSize: FontSz.xs,
                    padding: context.padSym(h: Insets.x2, v: Insets.x1),
                  ),
                )
              : null,
        ),
      if (outcome != null)
        VisitDetailRow(
          icon: Icons.task_alt,
          label: context.s.wfFieldOutcome,
          value: outcome,
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return VisitSection(
      icon: Icons.route_outlined,
      title: context.s.wfSectionExecution,
      rows: rows,
    );
  }

  /// Where a check-in / check-out happened: the recorded place name, else the
  /// coordinates, plus an "open in maps" button when there is a coordinate.
  /// Null when neither was recorded.
  static Widget? _placeRow(
    BuildContext context, {
    required IconData icon,
    required Color tone,
    required String label,
    required double? latitude,
    required double? longitude,
    required String? place,
  }) {
    final hasFix = latitude != null && longitude != null;
    final text =
        place ??
        (hasFix
            ? LocationDescriber.formatCoordinates(latitude, longitude)
            : null);
    if (text == null) return null;
    return VisitDetailRow(
      icon: icon,
      iconColor: tone,
      label: label,
      value: text,
      trailing: hasFix
          ? VisitMapsPill(
              latitude: latitude,
              longitude: longitude,
              label: place,
            )
          : null,
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
    // Nobody decides on their own participation (API.md §4.4).
    if (u.employeeId != null && u.employeeId == participant.employeeId) {
      return false;
    }
    // A manager in the attendee's own chain decides; the line only names the
    // direct one, so other managers are left to the server's hierarchy check
    // and visit administrators may always act.
    final isTheirManager =
        u.employeeId != null && u.employeeId == participant.managerId;
    return isTheirManager || u.canApproveVisits;
  }

  @override
  Widget build(BuildContext context) {
    final tone = participantStateColor(context, participant.approvalState);
    final cubit = context.read<VisitDetailCubit>();
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.r(Insets.x2)),
      child: Row(
        children: [
          IconBadge(
            icon: Icons.person_outline,
            color: tone,
            size: context.r(CompSz.badge),
            iconSize: context.r(IconSz.label),
          ),
          context.gapW(Insets.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  participant.employeeName ?? context.s.wfUnknownEmployee,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                context.gapH(Insets.hair),
                Text(
                  participantStateLabel(context, participant.approvalState),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium?.copyWith(
                    color: tone,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (_canAct) ...[
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.check_circle, color: context.visitSuccess),
              tooltip: context.s.wfApproveParticipant,
              onPressed: () => cubit.approveParticipant(participant.id),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.cancel, color: context.colors.error),
              tooltip: context.s.wfRejectParticipant,
              onPressed: () async {
                final reason = await showRejectReasonSheet(context);
                if (reason == null) return;
                await cubit.rejectParticipant(participant.id, reason);
              },
            ),
          ],
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
    String? at(DateTime? when) =>
        when == null ? null : df.format(when.toLocal());

    final submitted = visit.submittedDate;
    final escalated = visit.escalationDate;
    final approvedBy = visit.approvedByName;
    final rejectedBy = visit.rejectedByName;
    final reason = visit.rejectReason;
    final rows = <Widget>[
      if (submitted != null)
        VisitDetailRow(
          icon: Icons.send_outlined,
          label: context.s.wfSubmittedOn,
          value: df.format(submitted.toLocal()),
        ),
      if (visit.isEscalated && escalated != null)
        VisitDetailRow(
          icon: Icons.priority_high_rounded,
          iconColor: cs.error,
          label: context.s.wfEscalatedBadge,
          value: df.format(escalated.toLocal()),
        ),
      if (approvedBy != null)
        VisitDetailRow(
          icon: Icons.check_circle_outline,
          iconColor: context.visitSuccess,
          label: context.s.wfApprovedByOn,
          value: context.joinFacts([approvedBy, at(visit.approvedDate)]),
        ),
      if (rejectedBy != null)
        VisitDetailRow(
          icon: Icons.cancel_outlined,
          iconColor: cs.error,
          label: context.s.wfRejectedByOn,
          value: context.joinFacts([rejectedBy, at(visit.rejectedDate)]),
        ),
      if (reason != null)
        VisitDetailRow(
          icon: Icons.notes_outlined,
          iconColor: cs.error,
          label: context.s.wfReason,
          value: reason,
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
