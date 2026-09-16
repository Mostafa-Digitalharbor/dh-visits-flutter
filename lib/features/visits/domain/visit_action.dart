/// Everything a user can do to a visit from its detail screen.
///
/// These used to be bare strings (`'submit'`, `'start_queued'`, …) typed
/// independently in the cubit, the page that reacts to them and the offline
/// queue that replays them — a typo in any one of the three compiled fine and
/// silently skipped the reaction.
enum VisitAction {
  submit,
  approve,
  reject,
  cancel,
  reschedule,
  start,
  end,
  attachment,
  addParticipants,
  participantApprove,
  participantReject;

  /// The actions the offline queue can hold and replay. Everything else needs
  /// the server's answer before the screen can move on.
  bool get isQueueable => this == start || this == end;
}

/// How a finished [VisitAction] turned out, as the detail screen reports it.
class VisitActionOutcome {
  final VisitAction action;

  /// True when the action was saved on the device to be sent later, rather
  /// than accepted by the server.
  final bool queued;

  const VisitActionOutcome(this.action, {this.queued = false});

  @override
  bool operator ==(Object other) =>
      other is VisitActionOutcome &&
      other.action == action &&
      other.queued == queued;

  @override
  int get hashCode => Object.hash(action, queued);
}

/// Keys of a queued action's payload. Written by the detail cubit, read back
/// by `PendingActionsQueue` when it replays the action.
abstract final class QueuedVisitActionFields {
  static const type = 'type';
  static const latitude = 'latitude';
  static const longitude = 'longitude';
  static const location = 'location';
  static const outcome = 'outcome';
  static const isMocked = 'is_mocked';
}
