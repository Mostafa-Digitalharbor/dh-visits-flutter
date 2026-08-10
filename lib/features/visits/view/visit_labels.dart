import 'package:flutter/material.dart';

import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../data/models/visit.dart';
import '../data/models/visit_participant.dart';

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
      return Colors.orange.shade700;
    case VisitState.escalated:
      return cs.error;
    case VisitState.approved:
      return Colors.blue.shade700;
    case VisitState.inProgress:
      return Colors.green.shade600;
    case VisitState.done:
      return Colors.green.shade800;
    case VisitState.rejected:
    case VisitState.cancelled:
      return cs.error;
    case VisitState.unknown:
      return cs.outline;
  }
}

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
      return '';
  }
}

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
