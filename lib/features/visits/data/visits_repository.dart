import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/constants.dart';
import '../../../core/storage/session_storage.dart';
import '../../../core/utils/distance.dart';
import '../../attendance/data/attendance_repository.dart';
import 'models/visit.dart';
import 'models/visit_type.dart';

/// Visits live in a **dedicated custom model** (`x_dh_visit`) built on the
/// Odoo server: one real, manager-readable column per field (customer,
/// salesperson, date, type, check-in/out time + GPS, notes) plus a proper
/// approval workflow in `x_state`.
///
/// The server-side `x_state` (draft → submitted → approved / rejected) is the
/// manager's approval pipeline. The app's existing [VisitLifecycleState]
/// (draft / submit / under_review / done / cancel) is mapped onto it so the
/// mobile UI is untouched:
///
///   x_state            ⇄  app lifecycle
///   draft              ⇄  submit       (scheduled / in-progress, visible)
///   submitted          ⇄  under_review (checked out, awaiting the manager)
///   approved           ⇄  done         (manager approved)
///   rejected           ⇄  cancel       (manager rejected)
///
/// Visit *types* still reuse the standard `calendar.event.type` tags.
/// [_adaptVisit] reshapes a row into what `Visit.fromJson` expects, so the
/// blocs / UI stay the same.
class VisitsRepository {
  final ApiClient api;
  final SessionStorage session;

  /// Optional: when present, the salesperson's check-in / check-out is also
  /// mirrored to Odoo's `hr.attendance` (with GPS). Best-effort — failures
  /// here never block the visit write. Left null in the CLI tools.
  final AttendanceRepository? attendance;

  VisitsRepository({required this.api, required this.session, this.attendance});

  static final DateFormat _odooDateTime = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final DateFormat _odooDate = DateFormat('yyyy-MM-dd');

  static const List<String> _visitFields = [
    'id',
    'x_name',
    'x_visit_date',
    'x_partner_id',
    'x_user_id',
    'x_employee_id',
    'x_visit_type_id',
    'x_check_in_time',
    'x_check_out_time',
    'x_check_in_lat',
    'x_check_in_lng',
    'x_check_out_lat',
    'x_check_out_lng',
    'x_duration_minutes',
    'x_notes',
    'x_manager_note',
    'x_state',
    'x_customer_lat',
    'x_customer_lng',
    'x_customer_address',
    'x_customer_phone',
  ];

  // ---------------------------------------------------------------------------
  // State mapping between the server workflow and the app's lifecycle enum.
  // ---------------------------------------------------------------------------

  /// `x_state` (server) → the app's lifecycle wire string.
  String _xStateToAppWire(String? x) {
    switch (x) {
      case 'draft':
        return 'submit';
      case 'submitted':
        return 'under_review';
      case 'approved':
        return 'done';
      case 'rejected':
        return 'cancel';
      default:
        return 'submit';
    }
  }

  /// App lifecycle wire string → `x_state` (server).
  String _appWireToXState(String? appWire) {
    switch (appWire) {
      case 'under_review':
        return 'submitted';
      case 'done':
        return 'approved';
      case 'cancel':
        return 'rejected';
      case 'draft':
      case 'submit':
      default:
        return 'draft';
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<({int? uid, bool isManager})> _currentUser() async {
    final u = await session.getUser();
    if (u == null) return (uid: null, isManager: false);
    final uid = (u['uid'] as num?)?.toInt();
    final isManager = u['is_manager'] == true ||
        u['is_admin'] == true ||
        u['is_system'] == true;
    return (uid: uid, isManager: isManager);
  }

  /// Normalises any datetime representation to an ISO-8601 UTC string (`…Z`).
  String? _toIsoUtc(dynamic raw) {
    if (raw == null || raw == false) return null;
    if (raw is DateTime) return raw.toUtc().toIso8601String();
    var s = raw.toString().trim();
    if (s.isEmpty) return null;
    final hasMarker =
        s.endsWith('Z') || s.contains('+') || s.lastIndexOf('-') > 10;
    if (!hasMarker) s = '${s.replaceFirst(' ', 'T')}Z';
    return DateTime.tryParse(s)?.toUtc().toIso8601String();
  }

  /// Converts any datetime representation to Odoo's naive-UTC string format.
  String? _toOdooDateTime(dynamic raw) {
    final iso = _toIsoUtc(raw);
    if (iso == null) return null;
    return _odooDateTime.format(DateTime.parse(iso).toUtc());
  }

  double? _num(dynamic raw) => raw is num ? raw.toDouble() : null;

  /// A GPS coordinate, treating Odoo's unset-float default (0.0) as "absent".
  /// Real coordinates in the operating region are never exactly 0.
  double? _coord(dynamic raw) {
    final v = _num(raw);
    if (v == null || v == 0.0) return null;
    return v;
  }

  Map<String, dynamic>? _m2o(dynamic raw) {
    if (raw is List && raw.length >= 2) {
      return {'id': (raw[0] as num?)?.toInt(), 'name': raw[1]?.toString()};
    }
    return null;
  }

  String? _str(dynamic raw) =>
      (raw == null || raw == false) ? null : raw.toString();

  /// Converts an `x_dh_visit` row into the JSON shape `Visit.fromJson` expects.
  Map<String, dynamic> _adaptVisit(Map<String, dynamic> row) {
    final ciTime = _toIsoUtc(row['x_check_in_time']);
    final coTime = _toIsoUtc(row['x_check_out_time']);
    // GPS only meaningful once the matching timestamp exists.
    final ciLat = ciTime != null ? _coord(row['x_check_in_lat']) : null;
    final ciLng = ciTime != null ? _coord(row['x_check_in_lng']) : null;
    final coLat = coTime != null ? _coord(row['x_check_out_lat']) : null;
    final coLng = coTime != null ? _coord(row['x_check_out_lng']) : null;
    final custLat = _coord(row['x_customer_lat']);
    final custLng = _coord(row['x_customer_lng']);

    String? mobileState;
    if (coTime != null) {
      mobileState = 'checked_out';
    } else if (ciTime != null) {
      mobileState = 'checked_in';
    }

    int? durationMinutes;
    double? visitDuration;
    if (ciTime != null && coTime != null) {
      final d = DateTime.parse(coTime).difference(DateTime.parse(ciTime));
      if (!d.isNegative) {
        durationMinutes = d.inMinutes;
        visitDuration = d.inSeconds / 3600.0;
      }
    }

    String? rangeFor(double? lat, double? lng) {
      if (lat == null || lng == null) return null;
      if (custLat == null || custLng == null) return 'no';
      final dist = haversineMeters(custLat, custLng, lat, lng);
      return dist <= AppConstants.checkInRangeMeters
          ? 'in_range'
          : 'not_in_range';
    }

    String? visitDate;
    final dateRaw = row['x_visit_date'];
    if (dateRaw != null && dateRaw != false) {
      final s = dateRaw.toString();
      visitDate = s.length >= 10 ? s.substring(0, 10) : s;
    }

    final custM2o = _m2o(row['x_partner_id']);
    final vt = _m2o(row['x_visit_type_id']);
    final employee = _m2o(row['x_user_id']);

    final customerBlock = <String, dynamic>{
      'id': custM2o?['id'],
      'name': _str(row['x_name']) ?? custM2o?['name'],
      if (custLat != null) 'latitude': custLat,
      if (custLng != null) 'longitude': custLng,
      'address': _str(row['x_customer_address']),
      'phone': _str(row['x_customer_phone']),
    };

    return <String, dynamic>{
      'id': row['id'],
      'name': _str(row['x_name']),
      'visit_date': visitDate,
      'customer': customerBlock,
      'employee': employee,
      'visit_type':
          vt != null ? {'id': vt['id'], 'name': vt['name']} : null,
      'check_in_time': ciTime,
      'check_out_time': coTime,
      'duration_minutes': durationMinutes,
      'visit_duration': visitDuration,
      'state': _xStateToAppWire(_str(row['x_state'])),
      'mobile_state': mobileState,
      'description': _str(row['x_notes']),
      'check_in_lat': ciLat,
      'check_in_lng': ciLng,
      'check_out_lat': coLat,
      'check_out_lng': coLng,
      'check_in_state': rangeFor(ciLat, ciLng),
      'check_out_state': rangeFor(coLat, coLng),
    };
  }

  /// Reads a single visit and returns it in the adapted `Visit` JSON shape.
  Future<Map<String, dynamic>?> _readVisit(int id) async {
    final result = await api.jsonRpc(
      Endpoints.callKw,
      params: {
        'model': AppConstants.visitModel,
        'method': 'read',
        'args': [
          [id],
          _visitFields,
        ],
        'kwargs': {},
      },
    );
    final rows = result is List ? result : <dynamic>[];
    if (rows.isEmpty || rows.first is! Map) return null;
    return _adaptVisit(Map<String, dynamic>.from(rows.first as Map));
  }

  /// Customer snapshot fields (`x_customer_*`) pulled from a partner.
  Future<Map<String, dynamic>> _readPartnerSnapshot(int partnerId) async {
    final out = <String, dynamic>{};
    try {
      final result = await api.jsonRpc(
        Endpoints.callKw,
        params: {
          'model': AppConstants.partnerModel,
          'method': 'read',
          'args': [
            [partnerId],
            [
              'name',
              'partner_latitude',
              'partner_longitude',
              'contact_address',
              'phone'
            ],
          ],
          'kwargs': {},
        },
      );
      final rows = result is List ? result : <dynamic>[];
      if (rows.isEmpty || rows.first is! Map) return out;
      final r = Map<String, dynamic>.from(rows.first as Map);
      final lat = _num(r['partner_latitude']);
      final lng = _num(r['partner_longitude']);
      if (lat != null) out['x_customer_lat'] = lat;
      if (lng != null) out['x_customer_lng'] = lng;
      final addr = _str(r['contact_address']);
      if (addr != null) out['x_customer_address'] = addr;
      final phone = _str(r['phone']);
      if (phone != null) out['x_customer_phone'] = phone;
    } catch (_) {}
    return out;
  }

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  Future<List<Visit>> list({
    int? customerId,
    int? employeeId,
    DateTime? from,
    DateTime? to,
    String state = 'all',
    bool includeDrafts = false,
  }) async {
    final me = await _currentUser();
    final domain = <dynamic>[];
    // Field users only ever see their own visits (record rules enforce this
    // server-side too, but filtering keeps payloads small). Managers see all.
    if (!me.isManager && me.uid != null) {
      domain.add(['x_user_id', '=', me.uid]);
    }
    if (customerId != null) {
      domain.add(['x_partner_id', '=', customerId]);
    }
    if (employeeId != null) {
      domain.add(['x_user_id', '=', employeeId]);
    }
    if (from != null) {
      domain.add(['x_visit_date', '>=', _odooDate.format(from)]);
    }
    if (to != null) {
      domain.add(['x_visit_date', '<=', _odooDate.format(to)]);
    }

    final result = await api.jsonRpc(
      Endpoints.callKw,
      params: {
        'model': AppConstants.visitModel,
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': _visitFields,
          'order': 'x_visit_date desc, id desc',
        },
      },
    );
    final rows = result is List ? result : <dynamic>[];
    var visits = rows
        .whereType<Map>()
        .map((row) =>
            Visit.fromJson(_adaptVisit(Map<String, dynamic>.from(row))))
        .toList();

    if (!includeDrafts) {
      visits = visits
          .where((v) => v.lifecycleState != VisitLifecycleState.draft)
          .toList();
    }
    switch (state) {
      case 'checked_in':
        visits =
            visits.where((v) => v.state == VisitStateType.checkedIn).toList();
        break;
      case 'checked_out':
        visits =
            visits.where((v) => v.state == VisitStateType.checkedOut).toList();
        break;
    }
    return visits;
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Field-user check-in: creates a fresh visit already carrying the check-in
  /// timestamp + coordinates and the customer snapshot. Starts in `draft`
  /// (in-progress); it moves to `submitted` (awaiting the manager) on
  /// check-out.
  Future<Visit> checkIn({
    required int customerId,
    required double latitude,
    required double longitude,
    String? customerName,
    double? customerLat,
    double? customerLng,
    String? customerAddress,
    String? customerPhone,
    DateTime? timestamp,
  }) async {
    final me = await _currentUser();
    final now = (timestamp ?? DateTime.now().toUtc()).toUtc();
    final vals = <String, dynamic>{
      'x_name': (customerName == null || customerName.isEmpty)
          ? 'Visit'
          : customerName,
      'x_partner_id': customerId,
      if (me.uid != null) 'x_user_id': me.uid,
      'x_visit_date': _odooDate.format(now),
      'x_check_in_time': _odooDateTime.format(now),
      'x_check_in_lat': latitude,
      'x_check_in_lng': longitude,
      'x_state': 'draft',
      if (customerLat != null) 'x_customer_lat': customerLat,
      if (customerLng != null) 'x_customer_lng': customerLng,
      if (customerAddress != null) 'x_customer_address': customerAddress,
      if (customerPhone != null) 'x_customer_phone': customerPhone,
    };
    final result = await api.jsonRpc(
      Endpoints.callKw,
      params: {
        'model': AppConstants.visitModel,
        'method': 'create',
        'args': [vals],
        'kwargs': {},
      },
    );
    final id = (result as num).toInt();

    // Mirror the check-in into hr.attendance (GPS + time). Best-effort: a
    // failure here must not fail the visit check-in.
    try {
      await attendance?.checkIn(latitude: latitude, longitude: longitude);
    } catch (e) {
      debugPrint('[VisitsRepository] attendance check-in failed: $e');
    }

    final adapted = await _readVisit(id);
    return Visit.fromJson(adapted ?? {'id': id, ...vals});
  }

  /// Field-user check-out: records the check-out time + coordinates and moves
  /// the visit to `submitted` (awaiting the manager's approval).
  Future<Visit> checkOut({
    required int visitId,
    required double latitude,
    required double longitude,
    String? notes,
    DateTime? timestamp,
  }) async {
    final now = (timestamp ?? DateTime.now().toUtc()).toUtc();
    final vals = <String, dynamic>{
      'x_check_out_time': _odooDateTime.format(now),
      'x_check_out_lat': latitude,
      'x_check_out_lng': longitude,
      'x_state': 'submitted',
      if (notes != null && notes.trim().isNotEmpty) 'x_notes': notes.trim(),
    };
    await api.jsonRpc(
      Endpoints.callKw,
      params: {
        'model': AppConstants.visitModel,
        'method': 'write',
        'args': [
          [visitId],
          vals,
        ],
        'kwargs': {},
      },
    );

    // Mirror the check-out into hr.attendance (GPS + time). Best-effort.
    try {
      await attendance?.checkOut(latitude: latitude, longitude: longitude);
    } catch (e) {
      debugPrint('[VisitsRepository] attendance check-out failed: $e');
    }

    final adapted = await _readVisit(visitId);
    return Visit.fromJson(adapted ?? {'id': visitId, ...vals});
  }

  /// Admin: create a scheduled visit for a salesperson.
  Future<int> create({
    required int customerId,
    required int salespersonUserId,
    required DateTime visitDate,
    int? visitTypeId,
    String? visitTypeName,
    String? customerName,
    double? customerLat,
    double? customerLng,
    String? customerAddress,
    String? customerPhone,
    String? description,
    VisitLifecycleState state = VisitLifecycleState.submit,
  }) async {
    final vals = <String, dynamic>{
      'x_name': (customerName == null || customerName.isEmpty)
          ? 'Visit'
          : customerName,
      'x_partner_id': customerId,
      'x_user_id': salespersonUserId,
      'x_visit_date': _odooDate.format(visitDate),
      'x_state': _appWireToXState(lifecycleToWire(state)),
      if (visitTypeId != null) 'x_visit_type_id': visitTypeId,
      if (description != null && description.isNotEmpty) 'x_notes': description,
      if (customerLat != null) 'x_customer_lat': customerLat,
      if (customerLng != null) 'x_customer_lng': customerLng,
      if (customerAddress != null) 'x_customer_address': customerAddress,
      if (customerPhone != null) 'x_customer_phone': customerPhone,
    };
    final result = await api.jsonRpc(
      Endpoints.callKw,
      params: {
        'model': AppConstants.visitModel,
        'method': 'create',
        'args': [vals],
        'kwargs': {},
      },
    );
    return (result as num).toInt();
  }

  /// Generic partial update. Accepts the same Odoo-style field keys the UI
  /// already builds and maps them onto the `x_dh_visit` columns.
  Future<void> update(int visitId, Map<String, dynamic> partial) async {
    final vals = <String, dynamic>{};

    if (partial.containsKey('description')) {
      vals['x_notes'] = (partial['description'] ?? '').toString();
    }
    if (partial.containsKey('state')) {
      vals['x_state'] = _appWireToXState(partial['state']?.toString());
    }
    if (partial.containsKey('visit_date')) {
      vals['x_visit_date'] = partial['visit_date'].toString();
    }
    if (partial.containsKey('salesperson_id')) {
      vals['x_user_id'] = partial['salesperson_id'];
    }
    if (partial.containsKey('partner_id')) {
      final pid = (partial['partner_id'] as num).toInt();
      vals['x_partner_id'] = pid;
      // Refresh the customer snapshot so coords/in-range stay correct after a
      // re-assignment.
      vals.addAll(await _readPartnerSnapshot(pid));
    }
    if (partial.containsKey('visit_type_id')) {
      final raw = partial['visit_type_id'];
      vals['x_visit_type_id'] =
          (raw == false || raw == null) ? false : (raw as num).toInt();
    }
    if (partial.containsKey('check_in_date_time')) {
      vals['x_check_in_time'] = _toOdooDateTime(partial['check_in_date_time']);
    }
    if (partial.containsKey('check_in_lat')) {
      vals['x_check_in_lat'] = partial['check_in_lat'];
    }
    if (partial.containsKey('check_in_lng')) {
      vals['x_check_in_lng'] = partial['check_in_lng'];
    }
    if (partial.containsKey('check_out_date_time')) {
      vals['x_check_out_time'] = _toOdooDateTime(partial['check_out_date_time']);
    }
    if (partial.containsKey('check_out_lat')) {
      vals['x_check_out_lat'] = partial['check_out_lat'];
    }
    if (partial.containsKey('check_out_lng')) {
      vals['x_check_out_lng'] = partial['check_out_lng'];
    }

    if (vals.isEmpty) return;
    await api.jsonRpc(
      Endpoints.callKw,
      params: {
        'model': AppConstants.visitModel,
        'method': 'write',
        'args': [
          [visitId],
          vals,
        ],
        'kwargs': {},
      },
    );

    // Mirror an in-app check-in / check-out into hr.attendance so the user's
    // Odoo presence indicator flips green / red. Manager-created visits are
    // checked in/out through update() (not checkIn()/checkOut()), so without
    // this the systray dot would never change. Best-effort — an attendance
    // failure must never fail the visit write itself.
    final ciLat = partial['check_in_lat'];
    final ciLng = partial['check_in_lng'];
    if (ciLat is num && ciLng is num) {
      try {
        await attendance?.checkIn(
            latitude: ciLat.toDouble(), longitude: ciLng.toDouble());
      } catch (e) {
        debugPrint('[VisitsRepository] attendance check-in (update) failed: $e');
      }
    }
    final coLat = partial['check_out_lat'];
    final coLng = partial['check_out_lng'];
    if (coLat is num && coLng is num) {
      try {
        await attendance?.checkOut(
            latitude: coLat.toDouble(), longitude: coLng.toDouble());
      } catch (e) {
        debugPrint('[VisitsRepository] attendance check-out (update) failed: $e');
      }
    }
  }

  Future<void> delete(int visitId) async {
    await api.jsonRpc(
      Endpoints.callKw,
      params: {
        'model': AppConstants.visitModel,
        'method': 'unlink',
        'args': [
          [visitId],
        ],
        'kwargs': {},
      },
    );
  }

  /// Visit types map to standard `calendar.event.type` ("Tags"). Returns
  /// whatever the company has defined; empty if none.
  Future<List<VisitType>> listVisitTypes() async {
    final result = await api.jsonRpc(
      Endpoints.callKw,
      params: {
        'model': AppConstants.calendarEventTypeModel,
        'method': 'search_read',
        'args': [<dynamic>[]],
        'kwargs': {
          'fields': ['id', 'name'],
          'order': 'name asc',
        },
      },
    );
    final items = result is List ? result : <dynamic>[];
    return items
        .whereType<Map>()
        .map((e) => VisitType.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
