import 'package:equatable/equatable.dart';

import 'visit_participant.dart';
import '../../../../core/api/odoo_parse.dart';

// Re-exported: models and trackers across the app import the parser from here.
export '../../../../core/api/odoo_parse.dart' show parseOdooUtc;

/// The kind of thing a visit is attached to. The customer (`partner_id`)
/// auto-fills from the chosen project/opportunity server-side.
enum VisitType { project, opportunity, unknown }

VisitType visitTypeFromWire(String? raw) {
  switch (raw) {
    case 'project':
      return VisitType.project;
    case 'opportunity':
      return VisitType.opportunity;
    default:
      return VisitType.unknown;
  }
}

String? visitTypeToWire(VisitType t) {
  switch (t) {
    case VisitType.project:
      return 'project';
    case VisitType.opportunity:
      return 'opportunity';
    case VisitType.unknown:
      return null;
  }
}

/// Where one of a visit's two approval tracks stands (API.md §3):
/// `visit_approval_state` (the visit itself) and `attendee_approval_state`
/// (the roll-up of its attendees; `none` when it has none).
enum ApprovalTrack { none, pending, approved, rejected, unknown }

ApprovalTrack approvalTrackFromWire(String? raw) => switch (raw) {
      'none' => ApprovalTrack.none,
      'pending' => ApprovalTrack.pending,
      'approved' => ApprovalTrack.approved,
      'rejected' => ApprovalTrack.rejected,
      _ => ApprovalTrack.unknown,
    };

/// The full `dh.visit` approval workflow (11 states). See docs/VISITS_API.md.
enum VisitState {
  draft,
  submitted,
  waitingParticipantManagerApproval,
  waitingDirectManagerApproval,
  escalated,
  approved,
  rejected,
  cancelled,
  rescheduleRequested,
  inProgress,
  done,
  unknown,
}

const Map<String, VisitState> _stateFromWire = {
  'draft': VisitState.draft,
  'submitted': VisitState.submitted,
  'waiting_participant_manager_approval':
      VisitState.waitingParticipantManagerApproval,
  'waiting_direct_manager_approval': VisitState.waitingDirectManagerApproval,
  'escalated': VisitState.escalated,
  'approved': VisitState.approved,
  'rejected': VisitState.rejected,
  'cancelled': VisitState.cancelled,
  'reschedule_requested': VisitState.rescheduleRequested,
  'in_progress': VisitState.inProgress,
  'done': VisitState.done,
};

VisitState visitStateFromWire(String? raw) =>
    _stateFromWire[raw] ?? VisitState.unknown;

/// The `state` value Odoo stores for [state], or null for
/// [VisitState.unknown]. Server-side domains are built from this so the wire
/// spelling lives only in [_stateFromWire].
String? visitStateToWire(VisitState state) {
  for (final entry in _stateFromWire.entries) {
    if (entry.value == state) return entry.key;
  }
  return null;
}

/// A visit's record id, which every payload must carry. Throwing here (rather
/// than inventing an id) lets `parseRows` drop the one unreadable row.
int _requiredId(dynamic raw) =>
    odooInt(raw) ?? (throw const FormatException('visit row without an id'));

class Visit extends Equatable {
  final int id;

  /// Reference like `VIS/2026/00001`.
  final String? name;

  final VisitType visitType;
  final int? projectId;
  final String? projectName;
  final int? opportunityId;
  final String? opportunityName;

  /// Customer (auto-filled from the project/opportunity).
  final int? partnerId;
  final String? partnerName;

  /// Responsible employee.
  final int? employeeId;
  final String? employeeName;

  /// Approval chain (computed server-side from the employee hierarchy). Only
  /// present on the full `call_kw` read, not the REST payload.
  final int? directManagerId;
  final String? directManagerName;
  final int? higherManagerId;
  final String? higherManagerName;

  final DateTime? scheduledDatetime;
  final String? purpose;
  final String? location;
  final String? outcome;

  final VisitState state;

  /// The two approval tracks. Present on the REST payload; the full `call_kw`
  /// read leaves them [ApprovalTrack.unknown] and [attendeesPending] falls
  /// back to the participant lines it reads instead.
  final ApprovalTrack visitApprovalState;
  final ApprovalTrack attendeeApprovalState;

  /// Optional planned coordinates recorded on create.
  final double? latitude;
  final double? longitude;

  // Execution (GPS-stamped).
  final DateTime? startDatetime;
  final DateTime? endDatetime;
  final double? startLat;
  final double? startLng;
  final double? endLat;
  final double? endLng;
  final String? startLocation;
  final String? endLocation;

  // Approval history / escalation.
  final DateTime? submittedDate;
  final DateTime? approvedDate;
  final String? approvedByName;
  final DateTime? rejectedDate;
  final String? rejectedByName;
  final String? rejectReason;
  final bool isEscalated;
  final DateTime? escalationDate;

  final List<VisitParticipant> participants;

  /// Number of attachments (from `attachment_ids` length on the full read).
  final int attachmentCount;

  // -- GPS trail counters ------------------------------------------------------
  // Present on the REST payload (`/api/visit/my`, `get`, `create`). The full
  // `call_kw` read does NOT request them: they'd have to be added to
  // [odooReadFields], and a server whose `dh_visit_management` predates the
  // trail would then fail the entire detail read over two summary numbers. The
  // detail screen gets its counters from `/api/visit/track` instead, which
  // returns them alongside the points it is fetching anyway.

  /// Points currently on the trail.
  final int locationLogCount;

  /// Path length through those points, in kilometres, as measured by the
  /// server (we do not recompute it — the server owns the trail).
  final double trackedDistanceKm;

  /// Timestamp of the newest fix.
  final DateTime? lastLocationDatetime;

  const Visit({
    required this.id,
    this.name,
    this.visitType = VisitType.unknown,
    this.projectId,
    this.projectName,
    this.opportunityId,
    this.opportunityName,
    this.partnerId,
    this.partnerName,
    this.employeeId,
    this.employeeName,
    this.directManagerId,
    this.directManagerName,
    this.higherManagerId,
    this.higherManagerName,
    this.scheduledDatetime,
    this.purpose,
    this.location,
    this.outcome,
    this.state = VisitState.unknown,
    this.visitApprovalState = ApprovalTrack.unknown,
    this.attendeeApprovalState = ApprovalTrack.unknown,
    this.latitude,
    this.longitude,
    this.startDatetime,
    this.endDatetime,
    this.startLat,
    this.startLng,
    this.endLat,
    this.endLng,
    this.startLocation,
    this.endLocation,
    this.submittedDate,
    this.approvedDate,
    this.approvedByName,
    this.rejectedDate,
    this.rejectedByName,
    this.rejectReason,
    this.isEscalated = false,
    this.escalationDate,
    this.participants = const [],
    this.attachmentCount = 0,
    this.locationLogCount = 0,
    this.trackedDistanceKm = 0.0,
    this.lastLocationDatetime,
  });

  // --------------------------------------------------------------- derived
  bool get isProject => visitType == VisitType.project;

  /// An attendee still waits for their manager: the server refuses to approve
  /// the visit until none does (API.md §3, "attendees gate the approval").
  bool get attendeesPending =>
      attendeeApprovalState == ApprovalTrack.pending ||
      participants.any(
        (p) => p.approvalState == ParticipantApprovalState.pending,
      );
  bool get isOpportunity => visitType == VisitType.opportunity;

  bool get isInProgress => state == VisitState.inProgress;
  bool get isDone => state == VisitState.done;
  bool get isApproved => state == VisitState.approved;

  /// A visit can be started once approved.
  bool get canStart => state == VisitState.approved;

  /// A visit can be ended while it's running.
  bool get canEnd => state == VisitState.inProgress;

  /// The states `/api/visit/submit` accepts (API.md §4.2): a draft, a
  /// reschedule waiting to be sent, or a rejected visit sent back for approval.
  bool get canSubmit =>
      state == VisitState.draft ||
      state == VisitState.rescheduleRequested ||
      state == VisitState.rejected;

  /// States where a routed approver may approve/reject. The current backend
  /// routes a submitted visit straight to `submitted` (the single pending
  /// state); the `waiting_*` / `escalated` states also count as pending for
  /// forward-compatibility.
  bool get isAwaitingApproval =>
      state == VisitState.submitted ||
      state == VisitState.waitingParticipantManagerApproval ||
      state == VisitState.waitingDirectManagerApproval ||
      state == VisitState.escalated ||
      state == VisitState.rescheduleRequested;

  bool get isCancelled => state == VisitState.cancelled;
  bool get isRejected => state == VisitState.rejected;

  /// States from which the backend accepts `action_cancel`.
  ///
  /// Deliberately an allow-list. The action bar used to gate Cancel on a
  /// deny-list (`!done && !cancelled && !rejected && != inProgress`), which
  /// meant [VisitState.unknown] — anything a newer server sends that this build
  /// doesn't recognise — fell through and was offered a Cancel the backend may
  /// well refuse. An unrecognised state gets no destructive action.
  bool get canCancel => const {
    VisitState.draft,
    VisitState.submitted,
    VisitState.waitingParticipantManagerApproval,
    VisitState.waitingDirectManagerApproval,
    VisitState.escalated,
    VisitState.approved,
    VisitState.rescheduleRequested,
  }.contains(state);

  /// Best timestamp representing when the visit happened/will happen, for
  /// list grouping: end → start → scheduled.
  DateTime? get effectiveDate =>
      endDatetime ?? startDatetime ?? scheduledDatetime;

  Duration? get executionDuration {
    if (startDatetime == null || endDatetime == null) return null;
    final d = endDatetime!.difference(startDatetime!);
    return d.isNegative ? null : d;
  }

  bool get hasStartLocation => startLat != null && startLng != null;
  bool get hasEndLocation => endLat != null && endLng != null;

  /// Whether this visit has a GPS trail worth drawing. One lone point is a
  /// marker, not a path — the trail UI needs two to draw a line between.
  bool get hasTrail => locationLogCount > 1;

  /// A visit that is running right now is still collecting fixes, so anything
  /// read off it is a snapshot rather than the final path.
  bool get isTrackingLive => isInProgress;

  // -- Backward-compat aliases -------------------------------------------------
  // Peripheral, display-only screens (dashboard / analytics / route / customers)
  // were written against the old check-in/out model. These aliases map the new
  // fields onto the old names so those screens keep working without a full
  // rewrite. `in_progress` ≈ "checked in", `done` ≈ "checked out".
  int? get customerId => partnerId;
  String? get customerName => partnerName;
  DateTime? get checkInTime => startDatetime;
  DateTime? get checkOutTime => endDatetime;
  DateTime? get visitDate => scheduledDatetime;
  Duration? get visitDuration => executionDuration;
  int? get durationMinutes => executionDuration?.inMinutes;
  double? get checkInLat => startLat;
  double? get checkInLng => startLng;
  double? get checkOutLat => endLat;
  double? get checkOutLng => endLng;
  bool get hasCheckInLocation => hasStartLocation;
  bool get hasCheckOutLocation => hasEndLocation;
  // The visit's planned coordinates (`dh.visit.latitude/longitude`) stand in
  // for the "customer location" the old screens (Route map, geofence) expect.
  double? get customerLatitude => latitude;
  double? get customerLongitude => longitude;

  /// Whether the visit carries a usable planned coordinate.
  ///
  /// `0,0` counts as absent, not as a location. Odoo leaves `latitude` and
  /// `longitude` at `0.0` on every visit that was never geocoded — which is all
  /// of them on the live server — and a plain null-check treats that as a real
  /// fix. The Route map would then plot the day's stops in the Gulf of Guinea
  /// and compute the drive between them. `PartnerLocation` already applies this
  /// same 0-means-absent rule; this getter was the one place that didn't.
  bool get hasCustomerLocation =>
      latitude != null &&
      longitude != null &&
      !(latitude == 0 && longitude == 0);
  String? get visitTypeName => linkedRecordName;

  /// Whether the visit belongs to [day]'s calendar (local time), by its
  /// [effectiveDate]. The dashboard's "today" tile and the list it opens both
  /// ask this, so they can't disagree.
  bool isOnDay(DateTime day) {
    final date = effectiveDate?.toLocal();
    return date != null &&
        date.year == day.year &&
        date.month == day.month &&
        date.day == day.day;
  }

  /// Scheduled day has passed and the visit isn't completed/running/closed.
  bool get isOverdue => isOverdueAt(DateTime.now());

  /// [isOverdue] against an explicit clock.
  ///
  /// Aggregations take a `now` so their output is reproducible; reading the
  /// wall clock in here made the dashboard's "overdue" count ignore that
  /// injected clock, so the same visit list produced a different KPI depending
  /// on the day the code ran (and the metrics test started failing on its own
  /// weeks after it was written).
  bool isOverdueAt(DateTime now) {
    final s = scheduledDatetime;
    if (s == null) return false;
    if (isDone || isCancelled || isRejected || state == VisitState.inProgress) {
      return false;
    }
    return _localDay(s).isBefore(_localDay(now));
  }

  /// Whole-day delta between scheduled day and when it actually ended.
  int? get executionDaysDelta {
    final s = scheduledDatetime;
    final e = endDatetime;
    if (s == null || e == null) return null;
    // Calendar days, not 24h spans: `difference` across a DST change is 23 or
    // 25 hours, which `inDays` would floor to the wrong count.
    final sd = _localDay(s);
    final ed = _localDay(e);
    return DateTime.utc(
      ed.year,
      ed.month,
      ed.day,
    ).difference(DateTime.utc(sd.year, sd.month, sd.day)).inDays;
  }

  /// The calendar day [at] falls on for the user.
  ///
  /// The server's datetimes are UTC, so their `year/month/day` are the UTC
  /// date. Reading those straight off put a visit booked for 01:00 in Cairo
  /// (22:00 UTC the evening before) on the previous day: it showed as overdue
  /// on its own day and counted as a late finish in the on-time rate.
  static DateTime _localDay(DateTime at) {
    final local = at.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// The linked-record display name (project or opportunity).
  String? get linkedRecordName =>
      isProject ? projectName : (isOpportunity ? opportunityName : null);

  // --------------------------------------------------------------- factories

  /// From the REST `_visit_to_dict` payload (slim shape used by
  /// `/api/visit/*`). many2one fields are bare ints + a `*_name` string.
  ///
  /// Throws [FormatException] only for a row without an id; every other field
  /// degrades to "absent" (Odoo sends `false` for an unset value of any type).
  factory Visit.fromApi(Map<String, dynamic> json) {
    return Visit(
      id: _requiredId(json['id']),
      name: odooString(json['name']),
      visitType: visitTypeFromWire(odooString(json['visit_type'])),
      projectId: _positiveId(json['project_id']),
      opportunityId: _positiveId(json['opportunity_id']),
      partnerId: _positiveId(json['partner_id']),
      partnerName: odooString(json['partner_name']),
      employeeId: _positiveId(json['employee_id']),
      employeeName: odooString(json['employee_name']),
      scheduledDatetime: parseOdooUtc(json['scheduled_datetime']),
      purpose: odooString(json['purpose']),
      location: odooString(json['location']),
      outcome: odooString(json['outcome']),
      state: visitStateFromWire(odooString(json['state'])),
      visitApprovalState:
          approvalTrackFromWire(odooString(json['visit_approval_state'])),
      attendeeApprovalState:
          approvalTrackFromWire(odooString(json['attendee_approval_state'])),
      startDatetime: parseOdooUtc(json['start_datetime']),
      endDatetime: parseOdooUtc(json['end_datetime']),
      locationLogCount: odooInt(json['location_log_count']) ?? 0,
      trackedDistanceKm: odooDouble(json['tracked_distance_km']) ?? 0.0,
      lastLocationDatetime: parseOdooUtc(json['last_location_datetime']),
    );
  }

  /// A many2one sent as a bare id by the REST payload, where `0` also means
  /// "not set".
  static int? _positiveId(dynamic raw) {
    final id = odooInt(raw);
    return id == null || id == 0 ? null : id;
  }

  /// From a full `call_kw` read on `dh.visit` (rich shape: managers, approval
  /// history, escalation, start/end GPS). `participants` is passed separately
  /// after reading `dh.visit.participant`.
  factory Visit.fromOdooRow(
    Map<String, dynamic> row, {
    List<VisitParticipant> participants = const [],
  }) {
    final project = odooMany2one(row['project_id']);
    final opp = odooMany2one(row['opportunity_id']);
    final partner = odooMany2one(row['partner_id']);
    final employee = odooMany2one(row['employee_id']);
    final directMgr = odooMany2one(row['direct_manager_id']);
    final higherMgr = odooMany2one(row['higher_manager_id']);

    return Visit(
      id: _requiredId(row['id']),
      name: odooString(row['name']),
      visitType: visitTypeFromWire(odooString(row['visit_type'])),
      projectId: project.id,
      projectName: project.name,
      opportunityId: opp.id,
      opportunityName: opp.name,
      partnerId: partner.id,
      partnerName: partner.name,
      employeeId: employee.id,
      employeeName: employee.name,
      directManagerId: directMgr.id,
      directManagerName: directMgr.name,
      higherManagerId: higherMgr.id,
      higherManagerName: higherMgr.name,
      scheduledDatetime: parseOdooUtc(row['scheduled_datetime']),
      purpose: odooString(row['purpose']),
      location: odooString(row['location']),
      outcome: odooString(row['outcome']),
      state: visitStateFromWire(odooString(row['state'])),
      latitude: odooCoord(row['latitude']),
      longitude: odooCoord(row['longitude']),
      startDatetime: parseOdooUtc(row['start_datetime']),
      endDatetime: parseOdooUtc(row['end_datetime']),
      startLat: odooCoord(row['start_latitude']),
      startLng: odooCoord(row['start_longitude']),
      endLat: odooCoord(row['end_latitude']),
      endLng: odooCoord(row['end_longitude']),
      startLocation: odooString(row['start_location']),
      endLocation: odooString(row['end_location']),
      submittedDate: parseOdooUtc(row['submitted_date']),
      approvedDate: parseOdooUtc(row['approved_date']),
      approvedByName: odooMany2one(row['approved_by']).name,
      rejectedDate: parseOdooUtc(row['rejected_date']),
      rejectedByName: odooMany2one(row['rejected_by']).name,
      rejectReason: odooString(row['reject_reason']),
      isEscalated: odooBool(row['is_escalated']),
      escalationDate: parseOdooUtc(row['escalation_date']),
      participants: participants,
      attachmentCount: odooList(row['attachment_ids']).length,
    );
  }

  Visit copyWith({
    VisitState? state,
    String? outcome,
    DateTime? startDatetime,
    DateTime? endDatetime,
    List<VisitParticipant>? participants,
    int? locationLogCount,
    double? trackedDistanceKm,
    DateTime? lastLocationDatetime,
  }) => Visit(
    id: id,
    name: name,
    visitType: visitType,
    projectId: projectId,
    projectName: projectName,
    opportunityId: opportunityId,
    opportunityName: opportunityName,
    partnerId: partnerId,
    partnerName: partnerName,
    employeeId: employeeId,
    employeeName: employeeName,
    directManagerId: directManagerId,
    directManagerName: directManagerName,
    higherManagerId: higherManagerId,
    higherManagerName: higherManagerName,
    scheduledDatetime: scheduledDatetime,
    purpose: purpose,
    location: location,
    outcome: outcome ?? this.outcome,
    state: state ?? this.state,
    visitApprovalState: visitApprovalState,
    attendeeApprovalState: attendeeApprovalState,
    latitude: latitude,
    longitude: longitude,
    startDatetime: startDatetime ?? this.startDatetime,
    endDatetime: endDatetime ?? this.endDatetime,
    startLat: startLat,
    startLng: startLng,
    endLat: endLat,
    endLng: endLng,
    startLocation: startLocation,
    endLocation: endLocation,
    submittedDate: submittedDate,
    approvedDate: approvedDate,
    approvedByName: approvedByName,
    rejectedDate: rejectedDate,
    rejectedByName: rejectedByName,
    rejectReason: rejectReason,
    isEscalated: isEscalated,
    escalationDate: escalationDate,
    participants: participants ?? this.participants,
    attachmentCount: attachmentCount,
    locationLogCount: locationLogCount ?? this.locationLogCount,
    trackedDistanceKm: trackedDistanceKm ?? this.trackedDistanceKm,
    lastLocationDatetime: lastLocationDatetime ?? this.lastLocationDatetime,
  );

  /// Fields fetched by the full `call_kw` detail/manager-list read.
  static const List<String> odooReadFields = [
    'id',
    'name',
    'visit_type',
    'project_id',
    'opportunity_id',
    'partner_id',
    'employee_id',
    'direct_manager_id',
    'higher_manager_id',
    'scheduled_datetime',
    'purpose',
    'location',
    'outcome',
    'state',
    'latitude',
    'longitude',
    'start_datetime',
    'end_datetime',
    'start_latitude',
    'start_longitude',
    'end_latitude',
    'end_longitude',
    'start_location',
    'end_location',
    'submitted_date',
    'approved_date',
    'approved_by',
    'rejected_date',
    'rejected_by',
    'reject_reason',
    'is_escalated',
    'escalation_date',
    'participant_ids',
    'attachment_ids',
  ];

  /// Every field the screens render. A shorter list made a `copyWith` that
  /// only changed the outcome, the participants or the trail counters compare
  /// equal to the original — and an emit Equatable deems unchanged is dropped.
  @override
  List<Object?> get props => [
    id,
    name,
    visitType,
    projectId,
    projectName,
    opportunityId,
    opportunityName,
    partnerId,
    partnerName,
    employeeId,
    employeeName,
    directManagerId,
    directManagerName,
    higherManagerId,
    higherManagerName,
    scheduledDatetime,
    purpose,
    location,
    outcome,
    state,
    visitApprovalState,
    attendeeApprovalState,
    latitude,
    longitude,
    startDatetime,
    endDatetime,
    startLat,
    startLng,
    endLat,
    endLng,
    startLocation,
    endLocation,
    submittedDate,
    approvedDate,
    approvedByName,
    rejectedDate,
    rejectedByName,
    rejectReason,
    isEscalated,
    escalationDate,
    participants,
    attachmentCount,
    locationLogCount,
    trackedDistanceKm,
    lastLocationDatetime,
  ];
}
