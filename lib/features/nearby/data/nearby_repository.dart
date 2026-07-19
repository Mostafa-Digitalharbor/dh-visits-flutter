import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/odoo_rpc.dart';
import '../../../core/constants.dart';
import '../../../core/utils/distance.dart';
import '../../live_location/data/live_location_repository.dart';
import 'models/nearby_employee.dart';

/// Reads the live employee "presence" records (standard `calendar.event`
/// rows tagged by [LiveLocationRepository.presenceMarker]) and returns the
/// ones inside the requested radius of the customer office.
///
/// Distance + radius filtering is done client-side from the coordinates in
/// each presence record's meta blob — vanilla Odoo has no Haversine helper.
class NearbyRepository {
  final ApiClient api;
  NearbyRepository({required this.api});

  static final DateFormat _odooDateTime = DateFormat('yyyy-MM-dd HH:mm:ss');

  bool get isSupported => true;

  Future<List<NearbyEmployee>> fetch({
    required int customerId,
    double? customerLat,
    double? customerLng,
    double radius = 10,
    DateTime? since,
  }) async {
    // Default to "seen in the last few minutes" so stale employees drop off.
    final cutoff = (since ??
            DateTime.now().toUtc().subtract(AppConstants.nearbyOnlineWindow))
        .toUtc();

    final rows = await api.searchRead(
      AppConstants.calendarEventModel,
      domain: [
        ['description', 'like', LiveLocationRepository.presenceMarker],
        ['write_date', '>=', _odooDateTime.format(cutoff)],
      ],
      fields: const ['id', 'user_id', 'description', 'write_date'],
    );

    final employees = <NearbyEmployee>[];
    for (final row in rows) {
      final meta = LiveLocationRepository.decodeDescription(row['description']);
      final lat = (meta['lat'] as num?)?.toDouble();
      final lng = (meta['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;

      final user = row['user_id'];
      final userId =
          (user is List && user.isNotEmpty) ? (user[0] as num?)?.toInt() : null;
      final name = (user is List && user.length >= 2)
          ? user[1]?.toString() ?? ''
          : '';

      double distance = 0;
      if (customerLat != null && customerLng != null) {
        distance = haversineMeters(customerLat, customerLng, lat, lng);
        if (distance > radius) continue; // outside the radius — skip
      }

      employees.add(NearbyEmployee.fromJson({
        'employee_id': userId ?? 0,
        'name': name,
        'latitude': lat,
        'longitude': lng,
        'distance_meters': distance,
        'last_update': meta['t'],
      }));
    }

    employees.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return employees;
  }
}
