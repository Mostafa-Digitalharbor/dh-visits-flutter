import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import 'models/nearby_employee.dart';

class NearbyRepository {
  final ApiClient api;
  NearbyRepository({required this.api});

  Future<List<NearbyEmployee>> fetch({
    required int customerId,
    double radius = 10,
    DateTime? since,
  }) async {
    final data = await api.get(
      Endpoints.nearbyEmployees(customerId),
      queryParameters: {
        'radius': radius,
        if (since != null) 'since': since.toUtc().toIso8601String(),
      },
    );
    final items = data is List ? data : <dynamic>[];
    return items
        .whereType<Map>()
        .map((e) => NearbyEmployee.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
