import '../../../core/api/api_client.dart';
import '../../../core/api/odoo_rpc.dart';
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
    'is_company',
    'email',
    'function',
    'street',
    'city',
    'zip',
    'state_id',
    'country_id',
    'parent_id',
    'category_id',
    'website',
    'vat',
  ];

  /// Maps a `res.partner` row to the JSON shape `Customer.fromJson` expects.
  /// [categories] holds pre-resolved tag names (see [getById]).
  Map<String, dynamic> _adaptPartner(
    Map<String, dynamic> row, {
    List<String> categories = const [],
  }) {
    double? num0(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return null;
    }

    String? str0(dynamic raw) {
      if (raw == null || raw == false) return null;
      final s = raw.toString().trim();
      return s.isEmpty ? null : s;
    }

    // Unwrap an Odoo many2one (`[id, "Name"]` or `false`) to its name.
    String? m2oName(dynamic raw) {
      if (raw is List && raw.length >= 2) return str0(raw[1]);
      return null;
    }

    return <String, dynamic>{
      'id': row['id'],
      'name': str0(row['name']) ?? '',
      'latitude': num0(row['partner_latitude']) ?? 0.0,
      'longitude': num0(row['partner_longitude']) ?? 0.0,
      'address': str0(row['contact_address']),
      'phone': str0(row['phone']),
      'is_company': row['is_company'] == true,
      'email': str0(row['email']),
      'job_position': str0(row['function']),
      'street': str0(row['street']),
      'city': str0(row['city']),
      'zip': str0(row['zip']),
      'state_name': m2oName(row['state_id']),
      'country_name': m2oName(row['country_id']),
      'parent_name': m2oName(row['parent_id']),
      'website': str0(row['website']),
      'vat': str0(row['vat']),
      'categories': categories,
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

    final rows = await api.searchRead(
      AppConstants.partnerModel,
      domain: domain,
      fields: _fields,
      limit: limit,
      offset: offset,
      order: 'name asc',
    );
    return rows.map((e) => Customer.fromJson(_adaptPartner(e))).toList();
  }

  Future<Customer> getById(int id) async {
    final rows = await api.readRecords(AppConstants.partnerModel, [id], _fields);
    if (rows.isEmpty) {
      // Mirror the old "single record missing" behaviour with a typed error
      // so callers (Nearby map) fall back to the cached customer object.
      return Customer.fromJson(_adaptPartner({'id': id}));
    }
    final row = rows.first;
    // Resolve tag names: `category_id` comes back as bare ids from `read`.
    final categories = await _resolveCategories(row['category_id']);
    return Customer.fromJson(_adaptPartner(row, categories: categories));
  }

  /// Resolves `res.partner.category` ids to their display names (best-effort;
  /// an empty list on any failure so the detail page still renders).
  Future<List<String>> _resolveCategories(dynamic categoryIds) async {
    if (categoryIds is! List) return const [];
    final ids = categoryIds.whereType<num>().map((n) => n.toInt()).toList();
    if (ids.isEmpty) return const [];
    try {
      final rows = await api
          .readRecords(AppConstants.partnerCategoryModel, ids, ['name']);
      return rows
          .map((c) => c['name']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
