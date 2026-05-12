import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import 'models/customer.dart';

class CustomersRepository {
  final ApiClient api;
  CustomersRepository({required this.api});

  Future<List<Customer>> list({String? search, int limit = 50, int offset = 0}) async {
    final data = await api.get(
      Endpoints.customers,
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        'limit': limit,
        'offset': offset,
      },
    );
    final items = data is List ? data : <dynamic>[];
    return items
        .whereType<Map>()
        .map((e) => Customer.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Customer> getById(int id) async {
    final data = await api.get(Endpoints.customerById(id));
    return Customer.fromJson(Map<String, dynamic>.from(data));
  }
}
