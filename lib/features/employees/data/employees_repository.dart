import '../../../core/api/api_client.dart';
import '../../../core/api/odoo_rpc.dart';
import '../../../core/constants.dart';
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
    // `employee_id` (link to hr.employee) IS requested: the visit backend
    // (dh_visit_management) always has the HR module installed, and both the
    // participant picker and "plan for a subordinate" need the `hr.employee`
    // id — the participant/owner endpoints key off `employee_id`, not the
    // `res.users` id. Without it, `Employee.hrEmployeeId` is null and the
    // participant picker (which filters on `hrEmployeeId != null`) shows an
    // empty list, so no participant can ever be added.
    final rows = await api.searchRead(
      AppConstants.usersModel,
      domain: domain,
      fields: const ['id', 'login', 'name', 'employee_id'],
      limit: limit,
      order: 'name asc',
    );
    return rows.map((e) => Employee.fromJson(e)).toList();
  }
}
