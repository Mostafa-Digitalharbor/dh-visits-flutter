import '../../../core/api/api_client.dart';
import 'models/employee.dart';

/// Reads `res.users` filtered to the two Customer Visits groups (User +
/// Manager) so the picker only surfaces accounts that can actually receive
/// and act on a visit.
///
/// We don't have a dedicated REST endpoint for users, so everything goes
/// through Odoo's standard `/web/dataset/call_kw` JSON-RPC.
class EmployeesRepository {
  final ApiClient api;
  EmployeesRepository({required this.api});

  static const _userGroupXml = 'dh_customer_visits.group_customer_visit_user';
  static const _managerGroupXml =
      'dh_customer_visits.group_customer_visit_manager';

  List<int>? _cachedGroupIds;

  Future<List<int>> _resolveGroupIds() async {
    if (_cachedGroupIds != null) return _cachedGroupIds!;
    final ids = <int>[];
    for (final xml in [_userGroupXml, _managerGroupXml]) {
      final parts = xml.split('.');
      final result = await api.jsonRpc(
        '/web/dataset/call_kw',
        params: {
          'model': 'ir.model.data',
          'method': 'check_object_reference',
          'args': [parts[0], parts[1]],
          'kwargs': {},
        },
      );
      if (result is List && result.length >= 2) {
        final id = (result[1] as num).toInt();
        ids.add(id);
      }
    }
    _cachedGroupIds = ids;
    return ids;
  }

  Future<List<Employee>> list({String? search, int limit = 50}) async {
    final groupIds = await _resolveGroupIds();
    final domain = <dynamic>[
      ['share', '=', false],
      ['active', '=', true],
      ['all_group_ids', 'in', groupIds],
    ];
    if (search != null && search.isNotEmpty) {
      domain.add(['name', 'ilike', search]);
    }
    final result = await api.jsonRpc(
      '/web/dataset/call_kw',
      params: {
        'model': 'res.users',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': ['id', 'login', 'name', 'employee_id'],
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
