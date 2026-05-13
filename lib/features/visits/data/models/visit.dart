import 'package:equatable/equatable.dart';

enum VisitStateType { checkedIn, checkedOut, unknown }

/// Whether the employee's check-in / check-out GPS was within the
/// configured max distance from the customer office.
enum VisitRangeState { inRange, notInRange, pending, unknown }

/// Raw Odoo lifecycle state for `customer.visit.state`. We collapse
/// the four real values + `cancel` to a typed enum so the UI can show
/// a clean badge and the admin can write back via the same enum names.
///
/// Mobile-facing names: Draft / Submit / Done. The picker presents
/// these three; `underReview` (set automatically when the employee
/// checks out) is grouped with `submit` for display since work is
/// happening but the admin hasn't finalised it yet.
enum VisitLifecycleState { draft, submit, underReview, done, cancel, unknown }

VisitStateType _parseState(String? raw) {
  switch (raw) {
    case 'checked_in':
      return VisitStateType.checkedIn;
    case 'checked_out':
      return VisitStateType.checkedOut;
    default:
      return VisitStateType.unknown;
  }
}

VisitRangeState _parseRange(String? raw) {
  switch (raw) {
    case 'in_range':
      return VisitRangeState.inRange;
    case 'not_in_range':
      return VisitRangeState.notInRange;
    case 'no':
      return VisitRangeState.pending;
    default:
      return VisitRangeState.unknown;
  }
}

VisitLifecycleState _parseLifecycle(String? raw) {
  switch (raw) {
    case 'draft':
      return VisitLifecycleState.draft;
    case 'submit':
      return VisitLifecycleState.submit;
    case 'under_review':
      return VisitLifecycleState.underReview;
    case 'done':
      return VisitLifecycleState.done;
    case 'cancel':
      return VisitLifecycleState.cancel;
    default:
      return VisitLifecycleState.unknown;
  }
}

/// Inverse of `_parseLifecycle` — what we send back to Odoo when the
/// admin picks a new state from the mobile.
String? lifecycleToWire(VisitLifecycleState s) {
  switch (s) {
    case VisitLifecycleState.draft:
      return 'draft';
    case VisitLifecycleState.submit:
      return 'submit';
    case VisitLifecycleState.underReview:
      return 'under_review';
    case VisitLifecycleState.done:
      return 'done';
    case VisitLifecycleState.cancel:
      return 'cancel';
    case VisitLifecycleState.unknown:
      return null;
  }
}

/// Parses an Odoo datetime string as **UTC** (Odoo stores all datetimes
/// as UTC but serialises them without a timezone marker — e.g.
/// `"2026-05-12 11:00:00"`). If the string already carries an offset or
/// trailing `Z`, that's respected. The returned `DateTime` is always in
/// UTC so callers can convert to whatever timezone they want at display.
/// Converts Odoo's `visit_duration` (float, hours) to a `Duration`. Keeps
/// second-level precision so short visits aren't displayed as "0 min".
Duration? _parseHoursToDuration(dynamic raw) {
  if (raw == null || raw == false) return null;
  if (raw is! num) return null;
  if (raw <= 0) return null;
  final ms = (raw.toDouble() * 3600 * 1000).round();
  return Duration(milliseconds: ms);
}

DateTime? _parseOdooUtc(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final s = raw.trim();
  final hasMarker = s.endsWith('Z') ||
      s.contains('+') ||
      // A '-' beyond the date portion (idx 0-9) is a zone offset, not the
      // date separator.
      (s.lastIndexOf('-') > 10);
  final iso = hasMarker ? s : '${s}Z';
  return DateTime.tryParse(iso)?.toUtc();
}

class Visit extends Equatable {
  final int id;
  final String? name; // sequence like "VIS/00101"
  final int? customerId;
  final String? customerName;
  final int? employeeId;
  final String? employeeName;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final VisitStateType state;

  /// Raw Odoo lifecycle state. `state` above is the mobile-friendly
  /// derived view (checked_in / checked_out); this one is the actual
  /// 4-step workflow (draft → submit → under_review → done).
  final VisitLifecycleState lifecycleState;

  final int? durationMinutes;

  /// The high-resolution visit duration as exposed by Odoo's
  /// `visit_duration` field (float, in hours). Captures seconds too —
  /// short visits where `durationMinutes` rounds to 0 still have a
  /// meaningful `visitDuration`.
  final Duration? visitDuration;

  /// Employee GPS at the moment of check-in / check-out. Backend may not
  /// include them in the list response yet — parsed if present, otherwise
  /// null.
  final double? checkInLat;
  final double? checkInLng;
  final double? checkOutLat;
  final double? checkOutLng;

  /// Free-text notes (Odoo field: `description`). Editable by managers
  /// any time, and by users while they're checked-in.
  final String? description;

  /// The scheduled date for this visit (Odoo field: `visit_date`). The
  /// `/api/visits` REST response doesn't expose it yet (backend ask §10),
  /// but the mobile enriches the list via `call_kw` so it's available
  /// for client-side filtering.
  final DateTime? visitDate;

  /// Whether the employee's check-in / check-out coords were inside the
  /// customer's allowed radius. Computed on the server.
  final VisitRangeState checkInState;
  final VisitRangeState checkOutState;

  /// Customer office location + contact, inlined in the `/api/visits`
  /// response so the User-side detail page can render the map + Navigate
  /// button without a separate `/api/customers/<id>` fetch.
  final double? customerLatitude;
  final double? customerLongitude;
  final String? customerAddress;
  final String? customerPhone;

  /// `customer.visit.type` link — admin-tagged kind of visit (collection,
  /// demo, training…). Both id (for writing) and name (for display) are
  /// kept so the card can render the label without a second lookup.
  final int? visitTypeId;
  final String? visitTypeName;

  const Visit({
    required this.id,
    this.name,
    this.customerId,
    this.customerName,
    this.employeeId,
    this.employeeName,
    this.checkInTime,
    this.checkOutTime,
    this.state = VisitStateType.unknown,
    this.lifecycleState = VisitLifecycleState.unknown,
    this.durationMinutes,
    this.visitDuration,
    this.checkInLat,
    this.checkInLng,
    this.checkOutLat,
    this.checkOutLng,
    this.description,
    this.visitDate,
    this.checkInState = VisitRangeState.unknown,
    this.checkOutState = VisitRangeState.unknown,
    this.customerLatitude,
    this.customerLongitude,
    this.customerAddress,
    this.customerPhone,
    this.visitTypeId,
    this.visitTypeName,
  });

  bool get hasCheckInLocation => checkInLat != null && checkInLng != null;
  bool get hasCheckOutLocation => checkOutLat != null && checkOutLng != null;
  bool get hasCustomerLocation =>
      customerLatitude != null && customerLongitude != null;

  /// The date that best represents when the visit actually happened (or
  /// will happen), for filtering and grouping in the list. We prefer
  /// real timestamps over the scheduled date so a visit that ran early
  /// or late is bucketed by when it actually took place:
  ///
  /// 1. `checkOutTime`  — the visit finished, this is the truth.
  /// 2. `checkInTime`   — started but not finished yet.
  /// 3. `visitDate`     — still draft, only the scheduled day is known.
  ///
  /// Returns `null` if none of the three is set, which is rare but
  /// happens for legacy/imported records.
  DateTime? get effectiveDate =>
      checkOutTime ?? checkInTime ?? visitDate;

  /// True when the scheduled day passed but the visit isn't finished —
  /// the employee skipped the appointment. Drafts that should have
  /// happened yesterday and in-progress visits that linger past their
  /// scheduled day both light this up. Completed visits never overdue:
  /// even if they ran past their date, the work is done.
  bool get isOverdue {
    final scheduled = visitDate;
    if (scheduled == null) return false;
    // Treat done / under_review (checked-out) as finished work.
    if (lifecycleState == VisitLifecycleState.done ||
        lifecycleState == VisitLifecycleState.underReview ||
        state == VisitStateType.checkedOut) {
      return false;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scheduledDay =
        DateTime(scheduled.year, scheduled.month, scheduled.day);
    return scheduledDay.isBefore(today);
  }

  /// Whole-day delta between when the visit was scheduled and when the
  /// employee actually finished it. Only meaningful once `checkOutTime`
  /// is known. Negative = ran early, positive = ran late, 0 = on time.
  int? get executionDaysDelta {
    final scheduled = visitDate;
    final actual = checkOutTime;
    if (scheduled == null || actual == null) return null;
    final scheduledDay =
        DateTime(scheduled.year, scheduled.month, scheduled.day);
    final actualLocal = actual.toLocal();
    final actualDay =
        DateTime(actualLocal.year, actualLocal.month, actualLocal.day);
    return actualDay.difference(scheduledDay).inDays;
  }

  factory Visit.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'];
    final employee = json['employee'];
    final customerLatRaw = customer is Map
        ? (customer['latitude'] ?? customer['partner_latitude'])
        : null;
    final customerLngRaw = customer is Map
        ? (customer['longitude'] ?? customer['partner_longitude'])
        : null;
    return Visit(
      id: ((json['id'] ?? json['visit_id']) as num).toInt(),
      name: json['name']?.toString(),
      customerId: customer is Map
          ? (customer['id'] as num?)?.toInt()
          : (json['customer_id'] as num?)?.toInt(),
      customerName: customer is Map ? customer['name']?.toString() : null,
      employeeId: employee is Map
          ? (employee['id'] as num?)?.toInt()
          : (json['employee_id'] as num?)?.toInt(),
      employeeName: employee is Map ? employee['name']?.toString() : null,
      checkInTime: _parseOdooUtc(json['check_in_time']?.toString()),
      checkOutTime: _parseOdooUtc(json['check_out_time']?.toString()),
      state: _parseState(
          (json['mobile_state'] ?? json['state'])?.toString()),
      lifecycleState: _parseLifecycle(json['state']?.toString()),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      visitDuration: _parseHoursToDuration(json['visit_duration']),
      checkInLat: (json['check_in_lat'] as num?)?.toDouble(),
      checkInLng: (json['check_in_lng'] as num?)?.toDouble(),
      checkOutLat: (json['check_out_lat'] as num?)?.toDouble(),
      checkOutLng: (json['check_out_lng'] as num?)?.toDouble(),
      description: json['description']?.toString(),
      visitDate: json['visit_date'] != null
          ? DateTime.tryParse(json['visit_date'].toString())
          : null,
      checkInState: _parseRange(json['check_in_state']?.toString()),
      checkOutState: _parseRange(json['check_out_state']?.toString()),
      customerLatitude: (customerLatRaw as num?)?.toDouble(),
      customerLongitude: (customerLngRaw as num?)?.toDouble(),
      customerAddress:
          customer is Map ? customer['address']?.toString() : null,
      customerPhone: customer is Map ? customer['phone']?.toString() : null,
      visitTypeId: json['visit_type'] is Map
          ? (json['visit_type']['id'] as num?)?.toInt()
          : null,
      visitTypeName: json['visit_type'] is Map
          ? json['visit_type']['name']?.toString()
          : null,
    );
  }

  Visit copyWith({
    int? id,
    String? name,
    int? customerId,
    String? customerName,
    int? employeeId,
    String? employeeName,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    VisitStateType? state,
    VisitLifecycleState? lifecycleState,
    int? durationMinutes,
    Duration? visitDuration,
    double? checkInLat,
    double? checkInLng,
    double? checkOutLat,
    double? checkOutLng,
    String? description,
    DateTime? visitDate,
    VisitRangeState? checkInState,
    VisitRangeState? checkOutState,
    double? customerLatitude,
    double? customerLongitude,
    String? customerAddress,
    String? customerPhone,
    int? visitTypeId,
    String? visitTypeName,
  }) =>
      Visit(
        id: id ?? this.id,
        name: name ?? this.name,
        customerId: customerId ?? this.customerId,
        customerName: customerName ?? this.customerName,
        employeeId: employeeId ?? this.employeeId,
        employeeName: employeeName ?? this.employeeName,
        checkInTime: checkInTime ?? this.checkInTime,
        checkOutTime: checkOutTime ?? this.checkOutTime,
        state: state ?? this.state,
        lifecycleState: lifecycleState ?? this.lifecycleState,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        visitDuration: visitDuration ?? this.visitDuration,
        checkInLat: checkInLat ?? this.checkInLat,
        checkInLng: checkInLng ?? this.checkInLng,
        checkOutLat: checkOutLat ?? this.checkOutLat,
        checkOutLng: checkOutLng ?? this.checkOutLng,
        description: description ?? this.description,
        visitDate: visitDate ?? this.visitDate,
        checkInState: checkInState ?? this.checkInState,
        checkOutState: checkOutState ?? this.checkOutState,
        customerLatitude: customerLatitude ?? this.customerLatitude,
        customerLongitude: customerLongitude ?? this.customerLongitude,
        customerAddress: customerAddress ?? this.customerAddress,
        customerPhone: customerPhone ?? this.customerPhone,
        visitTypeId: visitTypeId ?? this.visitTypeId,
        visitTypeName: visitTypeName ?? this.visitTypeName,
      );

  @override
  List<Object?> get props => [id, state, checkInTime, checkOutTime];
}
