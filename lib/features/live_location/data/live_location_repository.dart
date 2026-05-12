import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';

class LiveLocationRepository {
  final ApiClient api;
  LiveLocationRepository({required this.api});

  Future<void> push({
    required double latitude,
    required double longitude,
    double? accuracy,
    DateTime? timestamp,
  }) async {
    await api.post(Endpoints.updateEmployeeLocation, data: {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': (timestamp ?? DateTime.now().toUtc()).toIso8601String(),
      if (accuracy != null) 'accuracy': accuracy,
    });
  }
}
