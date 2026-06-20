import '../../../core/api/api_client.dart';
import 'models/employee.dart';

/// Reads standard `res.users` (over generic JSON-RPC) for the Create-Visit /
/// re-assign picker. We mirror
/// Odoo's own `salesperson_id` field — any **internal** active user can
/// be a salesperson, including admins/managers themselves. Filtering
/// down to a single role on the mobile side was hiding real
/// salespersons (admins who *do* go on visits), so we now show the same
/// list the Odoo web UI shows.
///
/// We don't have a dedicated REST endpoint for users, so everything
/// goes through Odoo's standard `/web/dataset/call_kw` JSON-RPC.
class EmployeesRepository {
  final ApiClient api;
  EmployeesRepository({required this.api});

  Future<List<Employee>> list({String? search, int limit = 50}) async {
    final domain = <dynamic>[
      // share=false keeps portal / public users out — only internal
      // employees should ever be a salesperson.
      ['share', '=', false],
      ['active', '=', true],
    ];
    if (search != null && search.isNotEmpty) {
      domain.add(['name', 'ilike', search]);
    }
    // `employee_id` (link to hr.employee) is intentionally NOT requested:
    // the HR module may not be installed on a vanilla Odoo. We only need the
    // `res.users` id to assign as the salesperson.
    final result = await api.jsonRpc(
      '/web/dataset/call_kw',
      params: {
        'model': 'res.users',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': ['id', 'login', 'name'],
          'limit': limit,
          'order': 'name asc',
        },
      },
    );
    final items = result is List ? result : <dynamic>[];
    return items
        .whereType<Map>()
        .map((e) => Employee.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
