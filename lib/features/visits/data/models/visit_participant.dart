import 'package:equatable/equatable.dart';

import '../../../../core/api/odoo_parse.dart';

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

  /// From the slim REST `add_participants` payload
  /// (`{id, employee_id, approval_state}`).
  factory VisitParticipant.fromApi(Map<String, dynamic> json) {
    return VisitParticipant(
      // `employee_id` comes back `false` when the participant's hr.employee was
      // archived between the picker read and the create. Unguarded, that threw
      // inside CreateVisitBloc._onSubmit *after* the visit had been created —
      // the form reported failure, the user retried, and a duplicate visit was
      // filed against the customer.
      id: odooInt(json['id']) ?? 0,
      employeeId: odooInt(json['employee_id']),
      approvalState: participantStateFromWire(
        odooString(json['approval_state']),
      ),
    );
  }

  /// From a full `call_kw` read on `dh.visit.participant`. Throws
  /// [FormatException] for a row without an id, so `parseRows` skips it.
  factory VisitParticipant.fromOdooRow(Map<String, dynamic> row) {
    final emp = odooMany2one(row['employee_id']);
    final mgr = odooMany2one(row['manager_id']);
    return VisitParticipant(
      id:
          odooInt(row['id']) ??
          (throw const FormatException('participant row without an id')),
      employeeId: emp.id,
      employeeName: emp.name,
      managerId: mgr.id,
      managerName: mgr.name,
      approvalState: participantStateFromWire(
        odooString(row['approval_state']),
      ),
      rejectReason: odooString(row['reject_reason']),
    );
  }

  @override
  List<Object?> get props => [
    id,
    employeeId,
    employeeName,
    managerId,
    managerName,
    approvalState,
    rejectReason,
  ];
}
