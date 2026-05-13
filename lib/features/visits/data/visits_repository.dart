import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import 'models/visit.dart';
import 'models/visit_type.dart';

/// Maps a `search_read` row from `customer.visit` to the same JSON shape
/// the `/api/visits` REST endpoint normally returns, so `Visit.fromJson`
/// keeps working unchanged.
Map<String, dynamic> _adaptVisitRow(Map<String, dynamic> row) {
  Map<String, dynamic>? m2oBlock(dynamic raw) {
    if (raw is List && raw.length >= 2) {
      return {
        'id': (raw[0] as num?)?.toInt(),
        'name': raw[1]?.toString(),
      };
    }
    return null;
  }

  String? nullableStr(dynamic raw) {
    if (raw == null || raw == false) return null;
    final s = raw.toString();
    return s.isEmpty ? null : s;
  }

  double? nullableNum(dynamic raw) {
    if (raw == null || raw == false) return null;
    if (raw is num) return raw.toDouble();
    return null;
  }

  // Customer block: merge the partner_id Many2one with the customer.visit's
  // partner_lat/partner_lng so Visit.fromJson can read coords.
  final customerBlock = m2oBlock(row['partner_id']);
  if (customerBlock != null) {
    final lat = nullableNum(row['partner_lat']);
    final lng = nullableNum(row['partner_lng']);
    if (lat != null) customerBlock['latitude'] = lat;
    if (lng != null) customerBlock['longitude'] = lng;
  }

  // The visit's `employee_id` is a computed link to `hr.employee`, but
  // it stays empty for users without a linked employee record (portal
  // users, freshly-added accounts). Fall back to `salesperson_id` so
  // the mobile always shows a human-readable name in the Employee row.
  final employeeBlock =
      m2oBlock(row['employee_id']) ?? m2oBlock(row['salesperson_id']);

  final visitTypeBlock = m2oBlock(row['visit_type_id']);

  return <String, dynamic>{
    'id': row['id'],
    'name': nullableStr(row['name']),
    'visit_date': nullableStr(row['visit_date']),
    'customer': customerBlock,
    'employee': employeeBlock,
    'visit_type': visitTypeBlock,
    'check_in_time': nullableStr(row['check_in_date_time']),
    'check_out_time': nullableStr(row['check_out_date_time']),
    'duration_minutes': row['duration_minutes'],
    'visit_duration': row['visit_duration'],
    'state': nullableStr(row['state']),
    'mobile_state': nullableStr(row['mobile_state']),
    'description': nullableStr(row['description']),
    'check_in_lat': nullableNum(row['check_in_lat']),
    'check_in_lng': nullableNum(row['check_in_lng']),
    'check_out_lat': nullableNum(row['check_out_lat']),
    'check_out_lng': nullableNum(row['check_out_lng']),
    'check_in_state': nullableStr(row['check_in_state']),
    'check_out_state': nullableStr(row['check_out_state']),
  };
}

class VisitsRepository {
  final ApiClient api;
  VisitsRepository({required this.api});

  Future<Visit> checkIn({
    required int customerId,
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  }) async {
    final data = await api.post(
      Endpoints.checkIn,
      data: {
        'customer_id': customerId,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': (timestamp ?? DateTime.now().toUtc()).toIso8601String(),
      },
    );
    return Visit.fromJson(Map<String, dynamic>.from(data));
  }

  Future<Visit> checkOut({
    required int visitId,
    required double latitude,
    required double longitude,
    String? notes,
    DateTime? timestamp,
  }) async {
    final data = await api.post(
      Endpoints.checkOut,
      data: {
        'visit_id': visitId,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': (timestamp ?? DateTime.now().toUtc()).toIso8601String(),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return Visit.fromJson(Map<String, dynamic>.from(data));
  }

  /// Reads visits via Odoo's `search_read` so we don't depend on the
  /// `/api/visits` REST endpoint — that controller currently bleeds
  /// field-level access errors back as `AUTH_REQUIRED` when a non-manager
  /// reads the response (employee location fields). Going direct also
  /// gives us `visit_date` in the same round-trip.
  ///
  /// Backend record rules still scope the result by session user, so:
  /// - Manager (group 40): sees every visit.
  /// - User (group 39): sees only visits where `salesperson_id = user.id`.
  Future<List<Visit>> list({
    int? customerId,
    int? employeeId,
    DateTime? from,
    DateTime? to,
    String state = 'all',
    bool includeDrafts = false,
  }) async {
    final domain = <dynamic>[
      // Field employees only see visits that have been kicked off —
      // drafts are admin's WIP. Admins pass `includeDrafts: true` so
      // nothing is hidden from them.
      if (!includeDrafts) ['state', '!=', 'draft'],
    ];
    if (customerId != null) {
      domain.add(['partner_id', '=', customerId]);
    }
    if (employeeId != null) {
      domain.add(['employee_id', '=', employeeId]);
    }
    // `mobile_state` is a non-stored computed field — Odoo can't filter on
    // it via SQL. Map the mobile-friendly enum to the underlying stored
    // `state` lifecycle instead (draft → submit → under_review → done).
    switch (state) {
      case 'checked_in':
        domain.add(['state', '=', 'submit']);
        break;
      case 'checked_out':
        domain.add(['state', 'in', ['under_review', 'done']]);
        break;
      case 'all':
      default:
        break;
    }
    if (from != null) {
      domain.add(
          ['visit_date', '>=', DateFormat('yyyy-MM-dd').format(from)]);
    }
    if (to != null) {
      domain.add(
          ['visit_date', '<=', DateFormat('yyyy-MM-dd').format(to)]);
    }

    final result = await api.jsonRpc(
      '/web/dataset/call_kw',
      params: {
        'model': 'customer.visit',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': const [
            'id',
            'name',
            'visit_date',
            'partner_id',
            'partner_lat',
            'partner_lng',
            'employee_id',
            'salesperson_id',
            'visit_type_id',
            'check_in_date_time',
            'check_out_date_time',
            'duration_minutes',
            'visit_duration',
            'state',
            'mobile_state',
            'description',
            'check_in_lat',
            'check_in_lng',
            'check_out_lat',
            'check_out_lng',
            'check_in_state',
            'check_out_state',
          ],
          'order': 'visit_date desc, id desc',
        },
      },
    );
    final items = result is List ? result : <dynamic>[];
    return items
        .whereType<Map>()
        .map((row) =>
            Visit.fromJson(_adaptVisitRow(Map<String, dynamic>.from(row))))
        .toList();
  }

  /// Admin-only: update visit metadata. The backend doesn't expose a
  /// dedicated REST endpoint yet, so we go through Odoo's standard JSON-RPC
  /// `web/dataset/call_kw` on the `customer.visit` model.
  ///
  /// `partial` should contain only the fields being changed (e.g.
  /// `description`, `visit_date`, `visit_type_id`).
  Future<void> update(int visitId, Map<String, dynamic> partial) async {
    await api.jsonRpc(
      '/web/dataset/call_kw',
      params: {
        'model': 'customer.visit',
        'method': 'write',
        'args': [
          [visitId],
          partial,
        ],
        'kwargs': {},
      },
    );
  }

  /// Admin: create a brand-new visit for an assigned salesperson. Returns
  /// the new `customer.visit` id.
  ///
  /// `state` defaults to `submit` so created visits are visible in the
  /// mobile list straight away (the list hides drafts). Pass an explicit
  /// `VisitLifecycleState` from the create form to override.
  ///
  /// `name` and `employee_id` are intentionally not sent — `name` is
  /// auto-generated by `ir.sequence`, and `employee_id` is a computed
  /// RO field derived from `salesperson_id.employee_id`.
  Future<int> create({
    required int customerId,
    required int salespersonUserId,
    required DateTime visitDate,
    int? visitTypeId,
    String? description,
    VisitLifecycleState state = VisitLifecycleState.submit,
  }) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(visitDate);
    final payload = <String, dynamic>{
      'partner_id': customerId,
      'salesperson_id': salespersonUserId,
      'visit_date': dateStr,
      if (visitTypeId != null) 'visit_type_id': visitTypeId,
      if (description != null && description.isNotEmpty)
        'description': description,
    };
    final stateWire = lifecycleToWire(state);
    if (stateWire != null && stateWire != 'draft') {
      // Only override when picking something other than draft — keeps
      // the call payload minimal and lets Odoo's default kick in.
      payload['state'] = stateWire;
    }
    final result = await api.jsonRpc(
      '/web/dataset/call_kw',
      params: {
        'model': 'customer.visit',
        'method': 'create',
        'args': [payload],
        'kwargs': {},
      },
    );
    return (result as num).toInt();
  }

  /// Admin: hard-delete a visit. Calls Odoo's `unlink` so the record is
  /// gone from the DB (not just `state=cancel`). Backend record rules will
  /// reject the call for non-managers — the UI gates this to managers only.
  Future<void> delete(int visitId) async {
    await api.jsonRpc(
      '/web/dataset/call_kw',
      params: {
        'model': 'customer.visit',
        'method': 'unlink',
        'args': [
          [visitId],
        ],
        'kwargs': {},
      },
    );
  }

  /// Reads all available `customer.visit.type` records for the picker on
  /// the Create Visit form.
  Future<List<VisitType>> listVisitTypes() async {
    final result = await api.jsonRpc(
      '/web/dataset/call_kw',
      params: {
        'model': 'customer.visit.type',
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
