import '../../../core/api/api_client.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/api/odoo_parse.dart';
import '../../../core/api/odoo_rpc.dart';
import '../../../core/constants.dart';
import '../../../core/utils/app_log.dart';
import 'models/customer.dart';

/// Reads customers straight from the standard `res.partner` model over
/// Odoo's generic JSON-RPC (`call_kw`) — no custom REST controller.
///
/// Coordinates come from the `base_geolocalize` fields
/// (`partner_latitude` / `partner_longitude`), which the customer's Odoo
/// must have populated (Apps → install *Partner Geolocation*, then run
/// "Geo Localize" on the contacts). Partners without coordinates still appear
/// in the directory; map actions are disabled by the detail page until a
/// customer has usable coordinates.
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
  }) =>
      <String, dynamic>{
        'id': row['id'],
        'name': row['name'],
        'latitude': row['partner_latitude'],
        'longitude': row['partner_longitude'],
        'address': row['contact_address'],
        'phone': row['phone'],
        'is_company': row['is_company'],
        'email': row['email'],
        'job_position': row['function'],
        'street': row['street'],
        'city': row['city'],
        'zip': row['zip'],
        'state_name': odooMany2one(row['state_id']).name,
        'country_name': odooMany2one(row['country_id']).name,
        'parent_name': odooMany2one(row['parent_id']).name,
        'website': row['website'],
        'vat': row['vat'],
        'categories': categories,
      };

  Future<List<Customer>> list({
    String? search,
    int limit = AppConstants.directoryPageLimit,
    int offset = 0,
  }) async {
    // The customer directory must not disappear just because geocoding has not
    // been run on this database. Customer.hasCoordinates controls the map-only
    // actions separately on the detail page.
    final domain = <dynamic>[];
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
    // One unreadable partner is skipped, not allowed to empty the directory.
    final customers = parseRows(
      rows,
      (row) => Customer.fromJson(_adaptPartner(row)),
      label: 'CustomersRepository',
    );
    final lastVisits = await _lastVisits([for (final c in customers) c.id]);
    return [for (final c in customers) c.withLastVisit(lastVisits[c.id])];
  }

  /// One customer, with its tags and last visit.
  ///
  /// Throws `ApiException(notFound)` when the partner no longer exists or the
  /// user may no longer read it — Odoo's `read` then returns no row, and an
  /// empty customer rendered as a blank page with no explanation.
  Future<Customer> getById(int id) async {
    final rows = await api.readRecords(AppConstants.partnerModel, [id], _fields);
    if (rows.isEmpty) {
      throw ApiException(
        code: ApiErrorCode.notFound,
        details: '${AppConstants.partnerModel} $id is missing or not readable',
      );
    }
    final row = rows.first;
    // `category_id` comes back as bare ids from `read`; the names and the last
    // visit are independent lookups, so they share one round-trip.
    final (categories, lastVisits) = await (
      _resolveCategories(row['category_id']),
      _lastVisits([id]),
    ).wait;
    return Customer.fromJson(_adaptPartner(row, categories: categories))
        .withLastVisit(lastVisits[id]);
  }

  /// Resolves `res.partner.category` ids to their display names (best-effort;
  /// an empty list on any failure so the detail page still renders).
  Future<List<String>> _resolveCategories(dynamic categoryIds) async {
    final ids = odooList(categoryIds).map(odooInt).whereType<int>().toList();
    if (ids.isEmpty) return const [];
    try {
      final rows = await api.readRecords(
        AppConstants.partnerCategoryModel,
        ids,
        const ['name'],
      );
      return rows.map((c) => odooString(c['name'])).whereType<String>().toList();
    } catch (e) {
      appLog('[CustomersRepository] tag names unavailable: $e');
      return const [];
    }
  }

  /// The most recently started visit of each customer in [partnerIds].
  ///
  /// One `search_read` over the visits module, newest first, keeping the first
  /// row per customer. Bounded by [AppConstants.visitsAnalyticsLimit]: a
  /// customer whose last visit is older than that many visits across the page
  /// simply shows no badge. Best-effort — without the visits module, or
  /// without read access to it, the directory still loads, just unbadged.
  Future<Map<int, CustomerLastVisit>> _lastVisits(List<int> partnerIds) async {
    if (partnerIds.isEmpty) return const {};
    try {
      final rows = await api.searchRead(
        AppConstants.visitModel,
        domain: [
          [CustomerLastVisit.partnerField, 'in', partnerIds],
          [CustomerLastVisit.startField, '!=', false],
        ],
        fields: CustomerLastVisit.visitFields,
        order: '${CustomerLastVisit.startField} desc',
        limit: AppConstants.visitsAnalyticsLimit,
      );
      final latest = <int, CustomerLastVisit>{};
      for (final row in rows) {
        final partnerId = odooMany2one(row[CustomerLastVisit.partnerField]).id;
        if (partnerId == null || latest.containsKey(partnerId)) continue;
        try {
          latest[partnerId] = CustomerLastVisit.fromVisitRow(row);
        } on FormatException catch (e) {
          appLog('[CustomersRepository] skipped visit row: $e');
        }
      }
      return latest;
    } catch (e) {
      appLog('[CustomersRepository] last visits unavailable: $e');
      return const {};
    }
  }
}
