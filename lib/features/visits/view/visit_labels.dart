import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../data/models/visit.dart';
import '../data/models/visit_participant.dart';

/// How a visit is named on screen. Every list and header used to spell its own
/// fallback chain, and they disagreed on whether "#12" or the reference came
/// second.
extension VisitDisplay on Visit {
  /// The customer, else the visit reference, else "Visit #12".
  String displayTitle(BuildContext context) =>
      partnerName ?? name ?? context.s.visitFallbackTitle(id);

  /// The visit reference (`VIS/2026/00012`), else "Visit #12".
  String displayReference(BuildContext context) =>
      name ?? context.s.visitFallbackTitle(id);
}

/// The status tones the visit screens draw with.
///
/// Read through the theme's [AppX] where it is installed, and falling back to
/// the brand hues where it is not: widget tests pump single rows and badges in
/// a bare `MaterialApp`, where `context.x` would throw.
extension VisitTones on BuildContext {
  AppX? get _appX => Theme.of(this).extension<AppX>();

  /// Done, in range, recording — the positive outcome.
  Color get visitSuccess => _appX?.success ?? AppColors.green;

  /// A finished, closed-off success: darker than [visitSuccess] so a done
  /// visit reads apart from a running one.
  Color get visitSettled => _appX?.onSuccessContainer ?? AppColors.green;

  /// Waiting on someone, suspiciously short.
  Color get visitWarning => _appX?.warning ?? AppColors.amber;

  /// Approved and ready to go.
  Color get visitInfo => _appX?.info ?? AppColors.teal500;
}

/// Localized label for a workflow state.
String visitStateLabel(BuildContext context, VisitState state) {
  final s = context.s;
  switch (state) {
    case VisitState.draft:
      return s.wfStateDraft;
    case VisitState.submitted:
      return s.wfStateSubmitted;
    case VisitState.waitingParticipantManagerApproval:
      return s.wfStateWaitingParticipant;
    case VisitState.waitingDirectManagerApproval:
      return s.wfStateWaitingManager;
    case VisitState.escalated:
      return s.wfStateEscalated;
    case VisitState.approved:
      return s.wfStateApproved;
    case VisitState.rejected:
      return s.wfStateRejected;
    case VisitState.cancelled:
      return s.wfStateCancelled;
    case VisitState.rescheduleRequested:
      return s.wfStateReschedule;
    case VisitState.inProgress:
      return s.wfStateInProgress;
    case VisitState.done:
      return s.wfStateDone;
    case VisitState.unknown:
      return s.wfStateUnknown;
  }
}

/// A tone color for a workflow state badge.
Color visitStateColor(BuildContext context, VisitState state) {
  final cs = context.colors;
  switch (state) {
    case VisitState.draft:
      return cs.outline;
    case VisitState.submitted:
    case VisitState.waitingParticipantManagerApproval:
    case VisitState.waitingDirectManagerApproval:
    case VisitState.rescheduleRequested:
      return context.visitWarning;
    case VisitState.escalated:
      return cs.error;
    case VisitState.approved:
      return context.visitInfo;
    case VisitState.inProgress:
      return context.visitSuccess;
    case VisitState.done:
      return context.visitSettled;
    case VisitState.rejected:
    case VisitState.cancelled:
      return cs.error;
    case VisitState.unknown:
      return cs.outline;
  }
}

/// The type's name, or empty for an unrecognised one — callers join it with
/// other facts (see `joinFacts`), which drops empty parts.
String visitTypeLabel(BuildContext context, VisitType type) {
  switch (type) {
    case VisitType.project:
      return context.s.wfTypeProject;
    case VisitType.opportunity:
      return context.s.wfTypeOpportunity;
    case VisitType.unknown:
      return '';
  }
}

String participantStateLabel(BuildContext context, ParticipantApprovalState s) {
  switch (s) {
    case ParticipantApprovalState.pending:
      return context.s.wfParticipantPending;
    case ParticipantApprovalState.approved:
      return context.s.wfParticipantApprovedState;
    case ParticipantApprovalState.rejected:
      return context.s.wfParticipantRejectedState;
    case ParticipantApprovalState.unknown:
      return context.s.wfStateUnknown;
  }
}

/// The tone a participant's approval state is drawn in.
Color participantStateColor(
  BuildContext context,
  ParticipantApprovalState state,
) => switch (state) {
  ParticipantApprovalState.approved => context.visitSuccess,
  ParticipantApprovalState.rejected => context.colors.error,
  ParticipantApprovalState.pending => context.visitWarning,
  ParticipantApprovalState.unknown => context.colors.outline,
};

/// A compact pill showing a visit's workflow state.
class VisitStateBadge extends StatelessWidget {
  final VisitState state;
  const VisitStateBadge(this.state, {super.key});

  @override
  Widget build(BuildContext context) {
    return TonePill(
      label: visitStateLabel(context, state),
      color: visitStateColor(context, state),
    );
  }
}
