import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/constants.dart';
import 'models/customer.dart';

/// Reads customers straight from the standard `res.partner` model over
/// Odoo's generic JSON-RPC (`call_kw`) — no custom REST controller.
///
/// Coordinates come from the `base_geolocalize` fields
/// (`partner_latitude` / `partner_longitude`), which the customer's Odoo
/// must have populated (Apps → install *Partner Geolocation*, then run
/// "Geo Localize" on the contacts). Partners without coordinates are
/// filtered out — the app only plots customers it can place on a map.
class CustomersRepository {
  final ApiClient api;
  CustomersRepository({required this.api});

  // NB: `mobile` is intentionally absent — Odoo 17+ dropped `res.partner.mobile`
  // (consolidated into `phone`). Requesting it makes `search_read` throw
  // "Invalid field 'mobile'".
  static const List<String> _fields = [
    'id',
    'name',
    'partner_latitude',
    'partner_longitude',
    'contact_address',
    'phone',
  ];

  /// Maps a `res.partner` row to the JSON shape `Customer.fromJson` expects.
  Map<String, dynamic> _adaptPartner(Map<String, dynamic> row) {
    double? num0(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return null;
    }

    String? str0(dynamic raw) {
      if (raw == null || raw == false) return null;
      final s = raw.toString().trim();
      return s.isEmpty ? null : s;
    }

    return <String, dynamic>{
      'id': row['id'],
      'name': str0(row['name']) ?? '',
      'latitude': num0(row['partner_latitude']) ?? 0.0,
      'longitude': num0(row['partner_longitude']) ?? 0.0,
      'address': str0(row['contact_address']),
      'phone': str0(row['phone']),
      'mobile': str0(row['mobile']),
    };
  }

  Future<List<Customer>> list({
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    // Only partners we can place on a map (non-zero coordinates).
    final domain = <dynamic>[
      ['partner_latitude', '!=', 0],
      ['partner_longitude', '!=', 0],
    ];
    if (search != null && search.isNotEmpty) {
      // name OR phone match: ['|', (name ilike), (phone ilike)]
      domain.add('|');
      domain.add(['name', 'ilike', search]);
      domain.add(['phone', 'ilike', search]);
    }

    final result = await api.jsonRpc(
      Endpoints.callKw,
      params: {
        'model': AppConstants.partnerModel,
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': _fields,
          'limit': limit,
          'offset': offset,
          'order': 'name asc',
        },
      },
    );
    final items = result is List ? result : <dynamic>[];
    return items
        .whereType<Map>()
        .map((e) => Customer.fromJson(_adaptPartner(Map<String, dynamic>.from(e))))
        .toList();
  }

  Future<Customer> getById(int id) async {
    final result = await api.jsonRpc(
      Endpoints.callKw,
      params: {
        'model': AppConstants.partnerModel,
        'method': 'read',
        'args': [
          [id],
          _fields,
        ],
        'kwargs': {},
      },
    );
    final rows = result is List ? result : <dynamic>[];
    if (rows.isEmpty || rows.first is! Map) {
      // Mirror the old "single record missing" behaviour with a typed error
      // so callers (Nearby map) fall back to the cached customer object.
      return Customer.fromJson(_adaptPartner({'id': id}));
    }
    return Customer.fromJson(
        _adaptPartner(Map<String, dynamic>.from(rows.first as Map)));
  }
}
