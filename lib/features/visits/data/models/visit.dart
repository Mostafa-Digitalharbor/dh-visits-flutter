import 'package:equatable/equatable.dart';

import 'visit_participant.dart';

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

/// Parses an Odoo datetime string as **UTC**. Odoo stores/serialises datetimes
/// as naive UTC (`"2026-07-01 09:00:00"`); the REST API returns ISO
/// (`"2026-07-01T09:00:00"`). Either way there's no zone marker, so we append
/// `Z`. A trailing `Z`/offset already present is respected.
DateTime? parseOdooUtc(dynamic raw) {
  if (raw == null || raw == false) return null;
  final s = raw.toString().trim();
  if (s.isEmpty || s == 'false') return null;
  final hasMarker =
      s.endsWith('Z') || s.contains('+') || (s.lastIndexOf('-') > 10);
  final iso = hasMarker ? s : '${s.replaceFirst(' ', 'T')}Z';
  return DateTime.tryParse(iso)?.toUtc();
}

/// A GPS coordinate, treating Odoo's unset-float default (0.0) as "absent".
double? _coord(dynamic raw) {
  if (raw is! num) return null;
  final v = raw.toDouble();
  return v == 0.0 ? null : v;
}

/// Parses an Odoo many2one (`[id, "Name"]` or `false`), or a bare int id.
(int?, String?) _m2o(dynamic raw) {
  if (raw is List && raw.length >= 2) {
    return ((raw[0] as num?)?.toInt(), raw[1]?.toString());
  }
  if (raw is num) return (raw.toInt(), null);
  return (null, null);
}

String? _str(dynamic raw) =>
    (raw == null || raw == false) ? null : raw.toString();

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
  bool get isOpportunity => visitType == VisitType.opportunity;

  bool get isInProgress => state == VisitState.inProgress;
  bool get isDone => state == VisitState.done;
  bool get isApproved => state == VisitState.approved;

  /// A visit can be started once approved.
  bool get canStart => state == VisitState.approved;

  /// A visit can be ended while it's running.
  bool get canEnd => state == VisitState.inProgress;

  /// Draft or a returned-to-draft visit the owner can submit.
  bool get canSubmit =>
      state == VisitState.draft || state == VisitState.rescheduleRequested;

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
  DateTime? get effectiveDate => endDatetime ?? startDatetime ?? scheduledDatetime;

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
    if (isDone ||
        isCancelled ||
        isRejected ||
        state == VisitState.inProgress) {
      return false;
    }
    final today = DateTime(now.year, now.month, now.day);
    final sd = DateTime(s.year, s.month, s.day);
    return sd.isBefore(today);
  }

  /// Whole-day delta between scheduled day and when it actually ended.
  int? get executionDaysDelta {
    final s = scheduledDatetime;
    final e = endDatetime;
    if (s == null || e == null) return null;
    final sd = DateTime(s.year, s.month, s.day);
    final el = e.toLocal();
    final ed = DateTime(el.year, el.month, el.day);
    return ed.difference(sd).inDays;
  }

  /// The linked-record display name (project or opportunity).
  String? get linkedRecordName =>
      isProject ? projectName : (isOpportunity ? opportunityName : null);

  // --------------------------------------------------------------- factories

  /// From the REST `_visit_to_dict` payload (slim shape used by
  /// `/api/visit/*`). many2one fields are bare ints + a `*_name` string.
  factory Visit.fromApi(Map<String, dynamic> json) {
    // Odoo serialises an unset many2one as `false` (a bool), not null/0, so we
    // must guard the cast — otherwise `false as num?` throws and breaks the
    // whole list parse.
    int? nz(dynamic v) {
      if (v is! num) return null;
      final n = v.toInt();
      return n == 0 ? null : n;
    }

    return Visit(
      id: (json['id'] as num).toInt(),
      name: _str(json['name']),
      visitType: visitTypeFromWire(json['visit_type']?.toString()),
      projectId: nz(json['project_id']),
      opportunityId: nz(json['opportunity_id']),
      partnerId: nz(json['partner_id']),
      partnerName: _str(json['partner_name']),
      employeeId: nz(json['employee_id']),
      employeeName: _str(json['employee_name']),
      scheduledDatetime: parseOdooUtc(json['scheduled_datetime']),
      purpose: _str(json['purpose']),
      location: _str(json['location']),
      outcome: _str(json['outcome']),
      state: visitStateFromWire(json['state']?.toString()),
      startDatetime: parseOdooUtc(json['start_datetime']),
      endDatetime: parseOdooUtc(json['end_datetime']),
      locationLogCount: (json['location_log_count'] as num?)?.toInt() ?? 0,
      trackedDistanceKm:
          (json['tracked_distance_km'] as num?)?.toDouble() ?? 0.0,
      lastLocationDatetime: parseOdooUtc(json['last_location_datetime']),
    );
  }

  /// From a full `call_kw` read on `dh.visit` (rich shape: managers, approval
  /// history, escalation, start/end GPS). `participants` is passed separately
  /// after reading `dh.visit.participant`.
  factory Visit.fromOdooRow(
    Map<String, dynamic> row, {
    List<VisitParticipant> participants = const [],
  }) {
    final project = _m2o(row['project_id']);
    final opp = _m2o(row['opportunity_id']);
    final partner = _m2o(row['partner_id']);
    final employee = _m2o(row['employee_id']);
    final directMgr = _m2o(row['direct_manager_id']);
    final higherMgr = _m2o(row['higher_manager_id']);
    final approvedBy = _m2o(row['approved_by']);
    final rejectedBy = _m2o(row['rejected_by']);

    return Visit(
      id: (row['id'] as num).toInt(),
      name: _str(row['name']),
      visitType: visitTypeFromWire(row['visit_type']?.toString()),
      projectId: project.$1,
      projectName: project.$2,
      opportunityId: opp.$1,
      opportunityName: opp.$2,
      partnerId: partner.$1,
      partnerName: partner.$2,
      employeeId: employee.$1,
      employeeName: employee.$2,
      directManagerId: directMgr.$1,
      directManagerName: directMgr.$2,
      higherManagerId: higherMgr.$1,
      higherManagerName: higherMgr.$2,
      scheduledDatetime: parseOdooUtc(row['scheduled_datetime']),
      purpose: _str(row['purpose']),
      location: _str(row['location']),
      outcome: _str(row['outcome']),
      state: visitStateFromWire(row['state']?.toString()),
      latitude: _coord(row['latitude']),
      longitude: _coord(row['longitude']),
      startDatetime: parseOdooUtc(row['start_datetime']),
      endDatetime: parseOdooUtc(row['end_datetime']),
      startLat: _coord(row['start_latitude']),
      startLng: _coord(row['start_longitude']),
      endLat: _coord(row['end_latitude']),
      endLng: _coord(row['end_longitude']),
      startLocation: _str(row['start_location']),
      endLocation: _str(row['end_location']),
      submittedDate: parseOdooUtc(row['submitted_date']),
      approvedDate: parseOdooUtc(row['approved_date']),
      approvedByName: approvedBy.$2,
      rejectedDate: parseOdooUtc(row['rejected_date']),
      rejectedByName: rejectedBy.$2,
      rejectReason: _str(row['reject_reason']),
      isEscalated: row['is_escalated'] == true,
      escalationDate: parseOdooUtc(row['escalation_date']),
      participants: participants,
      attachmentCount:
          (row['attachment_ids'] is List) ? (row['attachment_ids'] as List).length : 0,
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
  }) =>
      Visit(
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
        lastLocationDatetime:
            lastLocationDatetime ?? this.lastLocationDatetime,
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

  @override
  List<Object?> get props => [id, state, scheduledDatetime, startDatetime, endDatetime];
}
