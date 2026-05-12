import 'package:equatable/equatable.dart';

enum VisitStateType { checkedIn, checkedOut, unknown }

/// Whether the employee's check-in / check-out GPS was within the
/// configured max distance from the customer office.
enum VisitRangeState { inRange, notInRange, pending, unknown }

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

/// Parses an Odoo datetime string as **UTC** (Odoo stores all datetimes
/// as UTC but serialises them without a timezone marker — e.g.
/// `"2026-05-12 11:00:00"`). If the string already carries an offset or
/// trailing `Z`, that's respected. The returned `DateTime` is always in
/// UTC so callers can convert to whatever timezone they want at display.
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
  final int? durationMinutes;

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
    this.durationMinutes,
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
  });

  bool get hasCheckInLocation => checkInLat != null && checkInLng != null;
  bool get hasCheckOutLocation => checkOutLat != null && checkOutLng != null;
  bool get hasCustomerLocation =>
      customerLatitude != null && customerLongitude != null;

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
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
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
    int? durationMinutes,
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
        durationMinutes: durationMinutes ?? this.durationMinutes,
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
      );

  @override
  List<Object?> get props => [id, state, checkInTime, checkOutTime];
}
