import 'package:equatable/equatable.dart';

/// Approval state of a single additional participant on a visit. Each
/// participant's own manager must approve their participation before the main
/// (direct-manager) approval proceeds.
enum ParticipantApprovalState { pending, approved, rejected, unknown }

ParticipantApprovalState participantStateFromWire(String? raw) {
  switch (raw) {
    case 'pending':
      return ParticipantApprovalState.pending;
    case 'approved':
      return ParticipantApprovalState.approved;
    case 'rejected':
      return ParticipantApprovalState.rejected;
    default:
      return ParticipantApprovalState.unknown;
  }
}

/// A line of `dh.visit.participant`. Read via `call_kw` (the REST
/// `add_participants` endpoint returns a slim `{id, employee_id, approval_state}`
/// shape; the full detail view reads the rest).
class VisitParticipant extends Equatable {
  final int id;
  final int? employeeId;
  final String? employeeName;

  /// The participant's own manager (`manager_id`), auto-derived server-side —
  /// this is who must approve the participation.
  final int? managerId;
  final String? managerName;

  final ParticipantApprovalState approvalState;
  final String? rejectReason;

  const VisitParticipant({
    required this.id,
    this.employeeId,
    this.employeeName,
    this.managerId,
    this.managerName,
    this.approvalState = ParticipantApprovalState.unknown,
    this.rejectReason,
  });

  /// Parses an Odoo many2one, serialised as `[id, "Name"]` or `false`.
  static (int?, String?) _m2o(dynamic raw) {
    if (raw is List && raw.length >= 2) {
      return ((raw[0] as num?)?.toInt(), raw[1]?.toString());
    }
    return (null, null);
  }

  /// From the slim REST `add_participants` payload
  /// (`{id, employee_id, approval_state}`).
  factory VisitParticipant.fromApi(Map<String, dynamic> json) {
    return VisitParticipant(
      id: (json['id'] as num).toInt(),
      employeeId: (json['employee_id'] as num?)?.toInt(),
      approvalState: participantStateFromWire(json['approval_state']?.toString()),
    );
  }

  /// From a full `call_kw` read on `dh.visit.participant`.
  factory VisitParticipant.fromOdooRow(Map<String, dynamic> row) {
    final emp = _m2o(row['employee_id']);
    final mgr = _m2o(row['manager_id']);
    return VisitParticipant(
      id: (row['id'] as num).toInt(),
      employeeId: emp.$1,
      employeeName: emp.$2,
      managerId: mgr.$1,
      managerName: mgr.$2,
      approvalState: participantStateFromWire(row['approval_state']?.toString()),
      rejectReason: (row['reject_reason'] == false)
          ? null
          : row['reject_reason']?.toString(),
    );
  }

  @override
  List<Object?> get props => [id, employeeId, approvalState];
}
