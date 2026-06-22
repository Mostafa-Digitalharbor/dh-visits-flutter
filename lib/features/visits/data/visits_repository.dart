import 'dart:convert';

import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/constants.dart';
import '../../../core/storage/session_storage.dart';
import '../../../core/utils/distance.dart';
import 'models/visit.dart';
import 'models/visit_type.dart';

/// Visits live in the **standard** `calendar.event` model — no custom Odoo
/// module. Everything the app needs that vanilla Odoo has no field for
/// (check-in / check-out GPS + timestamps, the draft→done lifecycle, the
/// customer snapshot) is packed into a small JSON blob and stored inside the
/// event's `description`, fenced between markers and base64-encoded so
/// Odoo's HTML sanitiser leaves it intact.
///
/// Native `calendar.event` fields carry what maps naturally:
/// - `user_id`     → the salesperson
/// - `partner_ids` → the customer (relational link, for `partner_ids in […]`)
/// - `start`       → the scheduled visit datetime
/// - `categ_ids`   → the visit type ("Tags")
/// - `name`        → a human title (the customer name)
///
/// The matching `Visit` model shape is preserved by [_adaptEvent], so the
/// blocs / UI are untouched.
class VisitsRepository {
  final ApiClient api;
  final SessionStorage session;

  VisitsRepository({required this.api, required this.session});

  static final DateFormat _odooDateTime = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final DateFormat _odooDate = DateFormat('yyyy-MM-dd');

  static const String _metaStart = '⟦visit⟧';
  static const String _metaEnd = '⟦/visit⟧';

  static const List<String> _eventFields = [
    'id',
    'name',
    'start',
    'stop',
    'user_id',
    'partner_ids',
    'categ_ids',
    'description',
  ];

  // ---------------------------------------------------------------------------
  // Meta (de)serialisation — the app-specific payload kept in `description`.
  // ---------------------------------------------------------------------------

  /// Builds the `description` value: human-readable notes followed by the
  /// fenced, base64-encoded JSON meta block.
  String _encodeDescription(String notes, Map<String, dynamic> meta) {
    final encoded = base64.encode(utf8.encode(jsonEncode(meta)));
    final buf = StringBuffer();
    final trimmed = notes.trim();
    if (trimmed.isNotEmpty) {
      buf.writeln(trimmed);
      buf.writeln();
    }
    buf.write(_metaStart);
    buf.write(encoded);
    buf.write(_metaEnd);
    return buf.toString();
  }

  /// Splits a `description` value back into the readable notes and the meta
  /// map. Tolerates events created directly in Odoo Web (no meta block).
  ({String notes, Map<String, dynamic> meta}) _decodeDescription(dynamic raw) {
    final text = (raw == null || raw == false) ? '' : raw.toString();
    final start = text.indexOf(_metaStart);
    final end = text.indexOf(_metaEnd);
    if (start == -1 || end == -1 || end <= start) {
      return (notes: _stripHtml(text).trim(), meta: <String, dynamic>{});
    }
    final notes = _stripHtml(text.substring(0, start)).trim();
    final payload = text.substring(start + _metaStart.length, end);
    Map<String, dynamic> meta;
    try {
      meta = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(base64.decode(payload))) as Map);
    } catch (_) {
      meta = <String, dynamic>{};
    }
    return (notes: notes, meta: meta);
  }

  String _stripHtml(String s) => s
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<({int? uid, bool isManager})> _currentUser() async {
    final u = await session.getUser();
    if (u == null) return (uid: null, isManager: false);
    final uid = (u['uid'] as num?)?.toInt();
    final isManager =
        u['is_manager'] == true || u['is_admin'] == true || u['is_system'] == true;
    return (uid: uid, isManager: isManager);
  }

  /// Normalises any datetime representation (Odoo naive UTC string, ISO with
  /// or without `Z`) to an ISO-8601 UTC string with a trailing `Z`.
  String? _toIsoUtc(dynamic raw) {
    if (raw == null || raw == false) return null;
    if (raw is DateTime) return raw.toUtc().toIso8601String();
    var s = raw.toString().trim();
    if (s.isEmpty) return null;
    final hasMarker = s.endsWith('Z') || s.contains('+') || s.lastIndexOf('-') > 10;
    if (!hasMarker) s = '${s.replaceFirst(' ', 'T')}Z';
    return DateTime.tryParse(s)?.toUtc().toIso8601String();
  }

  double? _num(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return null;
  }

  Map<String, dynamic>? _m2o(dynamic raw) {
    if (raw is List && raw.length >= 2) {
      return {'id': (raw[0] as num?)?.toInt(), 'name': raw[1]?.toString()};
    }
    return null;
  }

  /// Converts a `calendar.event` row (+ decoded meta) into the JSON shape
  /// `Visit.fromJson` expects.
  Map<String, dynamic> _adaptEvent(Map<String, dynamic> row) {
    final decoded = _decodeDescription(row['description']);
    final meta = decoded.meta;

    final ci = meta['ci'] is Map ? Map<String, dynamic>.from(meta['ci']) : null;
    final co = meta['co'] is Map ? Map<String, dynamic>.from(meta['co']) : null;
    final cust =
        meta['cust'] is Map ? Map<String, dynamic>.from(meta['cust']) : null;
    final vt = meta['vt'] is Map ? Map<String, dynamic>.from(meta['vt']) : null;

    final ciTime = _toIsoUtc(ci?['t']);
    final coTime = _toIsoUtc(co?['t']);
    final ciLat = _num(ci?['lat']);
    final ciLng = _num(ci?['lng']);
    final coLat = _num(co?['lat']);
    final coLng = _num(co?['lng']);
    final custLat = _num(cust?['lat']);
    final custLng = _num(cust?['lng']);

    // Mobile state derived from presence of timestamps.
    String? mobileState;
    if (coTime != null) {
      mobileState = 'checked_out';
    } else if (ciTime != null) {
      mobileState = 'checked_in';
    }

    // Lifecycle state: stored in meta; default to something visible so that
    // events created in Odoo Web (no meta) aren't hidden as drafts.
    final lifecycle = (meta['state'] as String?) ??
        (coTime != null
            ? 'done'
            : ciTime != null
                ? 'submit'
                : 'submit');

    // Duration from the actual check-in / check-out times.
    int? durationMinutes;
    double? visitDuration;
    if (ciTime != null && coTime != null) {
      final d = DateTime.parse(coTime).difference(DateTime.parse(ciTime));
      if (!d.isNegative) {
        durationMinutes = d.inMinutes;
        visitDuration = d.inSeconds / 3600.0;
      }
    }

    // In-range badges, computed client-side from the customer office coords.
    String? rangeFor(double? lat, double? lng) {
      if (lat == null || lng == null) return null;
      if (custLat == null || custLng == null) return 'no';
      final dist = haversineMeters(custLat, custLng, lat, lng);
      return dist <= AppConstants.checkInRangeMeters ? 'in_range' : 'not_in_range';
    }

    // visit_date from the scheduled `start` (date portion only).
    String? visitDate;
    final startRaw = row['start'];
    if (startRaw != null && startRaw != false) {
      final s = startRaw.toString();
      visitDate = s.length >= 10 ? s.substring(0, 10) : s;
    }

    final employee = _m2o(row['user_id']);

    final customerBlock = <String, dynamic>{
      'id': (cust?['id'] as num?)?.toInt(),
      'name': cust?['name']?.toString() ?? row['name']?.toString(),
      if (custLat != null) 'latitude': custLat,
      if (custLng != null) 'longitude': custLng,
      'address': cust?['addr']?.toString(),
      'phone': cust?['phone']?.toString(),
    };

    return <String, dynamic>{
      'id': row['id'],
      'name': row['name']?.toString(),
      'visit_date': visitDate,
      'customer': customerBlock,
      'employee': employee,
      'visit_type':
          vt != null ? {'id': (vt['id'] as num?)?.toInt(), 'name': vt['name']} : null,
      'check_in_time': ciTime,
      'check_out_time': coTime,
      'duration_minutes': durationMinutes,
      'visit_duration': visitDuration,
      'state': lifecycle,
      'mobile_state': mobileState,
      'description': decoded.notes.isEmpty ? null : decoded.notes,
      'check_in_lat': ciLat,
      'check_in_lng': ciLng,
      'check_out_lat': coLat,
      'check_out_lng': coLng,
      'check_in_state': rangeFor(ciLat, ciLng),
      'check_out_state': rangeFor(coLat, coLng),
    };
  }

  Map<String, dynamic> _custSnapshot({
    required int id,
    String? name,
    double? lat,
    double? lng,
    String? address,
    String? phone,
  }) =>
      {
        'id': id,
        if (name != null) 'name': name,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (address != null) 'addr': address,
        if (phone != null) 'phone': phone,
      };

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
    // Only events this app created carry the meta marker in their
    // description — this keeps regular calendar meetings out of the list
    // (we share Odoo's standard `calendar.event` model with them).
    final domain = <dynamic>[
      ['description', 'like', _metaStart],
    ];
    // Field users only ever see their own visits. Managers (admin/system)
    // bypass record rules and see everything.
    if (!me.isManager && me.uid != null) {
      domain.add(['user_id', '=', me.uid]);
    }
    if (customerId != null) {
      domain.add(['partner_ids', 'in', [customerId]]);
    }
    if (employeeId != null) {
      domain.add(['user_id', '=', employeeId]);
    }
    if (from != null) {
      domain.add(['start', '>=', '${_odooDate.format(from)} 00:00:00']);
    }
    if (to != null) {
      domain.add(['start', '<=', '${_odooDate.format(to)} 23:59:59']);
    }

    final result = await api.jsonRpc(
      Endpoints.callKw,
      params: {
        'model': AppConstants.calendarEventModel,
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': _eventFields,
          'order': 'start desc, id desc',
        },
      },
    );
    final rows = result is List ? result : <dynamic>[];
    var visits = rows
        .whereType<Map>()
        .map((row) => Visit.fromJson(_adaptEvent(Map<String, dynamic>.from(row))))
        .toList();

    // Client-side filtering — the lifecycle/mobile state lives in the meta
    // blob, so it can't be expressed as an Odoo domain.
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

  Future<({String notes, Map<String, dynamic> meta})> _readMeta(
      int visitId) async {
    final result = await api.jsonRpc(
      Endpoints.callKw,
      params: {
        'model': AppConstants.calendarEventModel,
        'method': 'read',
        'args': [
          [visitId],
          ['description'],
        ],
        'kwargs': {},
      },
    );
    final rows = result is List ? result : <dynamic>[];
    if (rows.isEmpty || rows.first is! Map) {
      return (notes: '', meta: <String, dynamic>{});
    }
    return _decodeDescription((rows.first as Map)['description']);
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Field-user check-in: creates a fresh `calendar.event` already in the
  /// `submit` state with the check-in timestamp + coordinates recorded.
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
    final meta = <String, dynamic>{
      'v': 1,
      'state': 'submit',
      'ci': {'t': now.toIso8601String(), 'lat': latitude, 'lng': longitude},
      'cust': _custSnapshot(
        id: customerId,
        name: customerName,
        lat: customerLat,
        lng: customerLng,
        address: customerAddress,
        phone: customerPhone,
      ),
    };
    final vals = <String, dynamic>{
      'name': (customerName == null || customerName.isEmpty)
          ? 'Visit'
          : customerName,
      'start': _odooDateTime.format(now),
      'stop': _odooDateTime.format(now.add(const Duration(hours: 1))),
      'partner_ids': [
        [6, 0, [customerId]],
      ],
      if (me.uid != null) 'user_id': me.uid,
      'description': _encodeDescription('', meta),
    };
    final result = await api.jsonRpc(
      Endpoints.callKw,
      params: {
        'model': AppConstants.calendarEventModel,
        'method': 'create',
        'args': [vals],
        'kwargs': {},
      },
    );
    final id = (result as num).toInt();
    return Visit.fromJson(_adaptEvent({
      'id': id,
      'name': vals['name'],
      'start': vals['start'],
      'user_id': me.uid != null ? [me.uid, ''] : false,
      'partner_ids': [customerId],
      'description': vals['description'],
    }));
  }

  Future<Visit> checkOut({
    required int visitId,
    required double latitude,
    required double longitude,
    String? notes,
    DateTime? timestamp,
  }) async {
    final current = await _readMeta(visitId);
    final meta = Map<String, dynamic>.from(current.meta);
    final now = (timestamp ?? DateTime.now().toUtc()).toUtc();
    meta['co'] = {'t': now.toIso8601String(), 'lat': latitude, 'lng': longitude};
    meta['state'] = 'under_review';
    final newNotes =
        (notes != null && notes.trim().isNotEmpty) ? notes.trim() : current.notes;
    // Keep stop >= start (Odoo constraint): realign the event window to the
    // actual check-in → check-out span so finishing before the booked slot
    // isn't rejected.
    final ciTime = meta['ci'] is Map ? (meta['ci'] as Map)['t'] : null;
    final ciDt = ciTime is String ? DateTime.tryParse(ciTime) : null;
    final startStr =
        ciDt != null ? _odooDateTime.format(ciDt.toUtc()) : _odooDateTime.format(now);
    await api.jsonRpc(
      Endpoints.callKw,
      params: {
        'model': AppConstants.calendarEventModel,
        'method': 'write',
        'args': [
          [visitId],
          {
            'description': _encodeDescription(newNotes, meta),
            'start': startStr,
            'stop': _odooDateTime.format(now),
          },
        ],
        'kwargs': {},
      },
    );
    return Visit.fromJson(_adaptEvent({
      'id': visitId,
      'description': _encodeDescription(newNotes, meta),
    }));
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
    final dateStr = _odooDate.format(visitDate);
    final stateWire = lifecycleToWire(state) ?? 'draft';
    final meta = <String, dynamic>{
      'v': 1,
      'state': stateWire,
      'cust': _custSnapshot(
        id: customerId,
        name: customerName,
        lat: customerLat,
        lng: customerLng,
        address: customerAddress,
        phone: customerPhone,
      ),
      if (visitTypeId != null)
        'vt': {'id': visitTypeId, if (visitTypeName != null) 'name': visitTypeName},
    };
    final vals = <String, dynamic>{
      'name': (customerName == null || customerName.isEmpty)
          ? 'Visit'
          : customerName,
      'start': '$dateStr 09:00:00',
      'stop': '$dateStr 10:00:00',
      'partner_ids': [
        [6, 0, [customerId]],
      ],
      'user_id': salespersonUserId,
      'description': _encodeDescription(description ?? '', meta),
      if (visitTypeId != null)
        'categ_ids': [
          [6, 0, [visitTypeId]],
        ],
    };
    final result = await api.jsonRpc(
      Endpoints.callKw,
      params: {
        'model': AppConstants.calendarEventModel,
        'method': 'create',
        'args': [vals],
        'kwargs': {},
      },
    );
    return (result as num).toInt();
  }

  /// Generic partial update. Accepts the same Odoo-style field keys the UI
  /// already builds (`description`, `visit_date`, `partner_id`,
  /// `salesperson_id`, `state`, `visit_type_id`, `check_in_*`, `check_out_*`)
  /// and maps them onto `calendar.event` fields + the meta blob.
  Future<void> update(int visitId, Map<String, dynamic> partial) async {
    final current = await _readMeta(visitId);
    final meta = Map<String, dynamic>.from(current.meta);
    var notes = current.notes;
    final vals = <String, dynamic>{};

    Map<String, dynamic> ciBlock() =>
        meta['ci'] is Map ? Map<String, dynamic>.from(meta['ci']) : <String, dynamic>{};
    Map<String, dynamic> coBlock() =>
        meta['co'] is Map ? Map<String, dynamic>.from(meta['co']) : <String, dynamic>{};

    if (partial.containsKey('description')) {
      notes = (partial['description'] ?? '').toString();
    }
    if (partial.containsKey('state')) {
      meta['state'] = partial['state'];
    }
    if (partial.containsKey('visit_date')) {
      final d = partial['visit_date'].toString();
      vals['start'] = '$d 09:00:00';
      vals['stop'] = '$d 10:00:00';
    }
    if (partial.containsKey('salesperson_id')) {
      vals['user_id'] = partial['salesperson_id'];
    }
    if (partial.containsKey('partner_id')) {
      final pid = (partial['partner_id'] as num).toInt();
      vals['partner_ids'] = [
        [6, 0, [pid]],
      ];
      // Refresh the customer snapshot so name/coords/in-range stay correct
      // after a re-assignment.
      final snap = await _readPartnerSnapshot(pid);
      meta['cust'] = snap ?? {'id': pid};
    }
    if (partial.containsKey('visit_type_id')) {
      final raw = partial['visit_type_id'];
      if (raw == false || raw == null) {
        vals['categ_ids'] = [
          [5],
        ];
        meta.remove('vt');
      } else {
        final id = (raw as num).toInt();
        vals['categ_ids'] = [
          [6, 0, [id]],
        ];
        meta['vt'] = {'id': id, 'name': await _typeName(id)};
      }
    }

    // Check-in / check-out coordinate + timestamp writes.
    if (partial.containsKey('check_in_date_time') ||
        partial.containsKey('check_in_lat') ||
        partial.containsKey('check_in_lng')) {
      final ci = ciBlock();
      if (partial.containsKey('check_in_date_time')) {
        ci['t'] = _toIsoUtc(partial['check_in_date_time']);
      }
      if (partial.containsKey('check_in_lat')) ci['lat'] = partial['check_in_lat'];
      if (partial.containsKey('check_in_lng')) ci['lng'] = partial['check_in_lng'];
      meta['ci'] = ci;
    }
    if (partial.containsKey('check_out_date_time') ||
        partial.containsKey('check_out_lat') ||
        partial.containsKey('check_out_lng')) {
      final co = coBlock();
      if (partial.containsKey('check_out_date_time')) {
        co['t'] = _toIsoUtc(partial['check_out_date_time']);
        final stopStr = partial['check_out_date_time'].toString();
        vals['stop'] = stopStr;
        // Odoo's calendar.event enforces stop >= start. The scheduled start
        // can be later than the actual check-out (e.g. finishing before the
        // booked slot), which would be rejected — so realign start to the
        // real check-in time (the true visit window). Falls back to the stop
        // time when no check-in timestamp is known.
        final ciTime = ciBlock()['t'];
        final ciDt = ciTime is String ? DateTime.tryParse(ciTime) : null;
        vals['start'] = ciDt != null ? _odooDateTime.format(ciDt.toUtc()) : stopStr;
      }
      if (partial.containsKey('check_out_lat')) co['lat'] = partial['check_out_lat'];
      if (partial.containsKey('check_out_lng')) co['lng'] = partial['check_out_lng'];
      meta['co'] = co;
    }

    vals['description'] = _encodeDescription(notes, meta);

    await api.jsonRpc(
      Endpoints.callKw,
      params: {
        'model': AppConstants.calendarEventModel,
        'method': 'write',
        'args': [
          [visitId],
          vals,
        ],
        'kwargs': {},
      },
    );
  }

  Future<Map<String, dynamic>?> _readPartnerSnapshot(int partnerId) async {
    try {
      final result = await api.jsonRpc(
        Endpoints.callKw,
        params: {
          'model': AppConstants.partnerModel,
          'method': 'read',
          'args': [
            [partnerId],
            ['name', 'partner_latitude', 'partner_longitude', 'contact_address', 'phone'],
          ],
          'kwargs': {},
        },
      );
      final rows = result is List ? result : <dynamic>[];
      if (rows.isEmpty || rows.first is! Map) return null;
      final r = Map<String, dynamic>.from(rows.first as Map);
      return _custSnapshot(
        id: partnerId,
        name: r['name']?.toString(),
        lat: _num(r['partner_latitude']),
        lng: _num(r['partner_longitude']),
        address: (r['contact_address'] == false) ? null : r['contact_address']?.toString(),
        phone: (r['phone'] == false) ? null : r['phone']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _typeName(int id) async {
    try {
      final result = await api.jsonRpc(
        Endpoints.callKw,
        params: {
          'model': AppConstants.calendarEventTypeModel,
          'method': 'read',
          'args': [
            [id],
            ['name'],
          ],
          'kwargs': {},
        },
      );
      final rows = result is List ? result : <dynamic>[];
      if (rows.isEmpty || rows.first is! Map) return null;
      final name = (rows.first as Map)['name'];
      return (name == null || name == false) ? null : name.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(int visitId) async {
    await api.jsonRpc(
      Endpoints.callKw,
      params: {
        'model': AppConstants.calendarEventModel,
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
