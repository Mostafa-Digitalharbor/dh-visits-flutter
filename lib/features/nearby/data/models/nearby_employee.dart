import 'package:equatable/equatable.dart';

class NearbyEmployee extends Equatable {
  final int employeeId;
  final String name;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final DateTime? lastUpdate;

  const NearbyEmployee({
    required this.employeeId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    this.lastUpdate,
  });

  factory NearbyEmployee.fromJson(Map<String, dynamic> json) => NearbyEmployee(
        employeeId: (json['employee_id'] as num).toInt(),
        name: (json['name'] ?? '').toString(),
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        distanceMeters: (json['distance_meters'] as num).toDouble(),
        lastUpdate: json['last_update'] != null
            ? DateTime.tryParse(json['last_update'].toString())?.toLocal()
            : null,
      );

  @override
  List<Object?> get props =>
      [employeeId, latitude, longitude, distanceMeters, lastUpdate];
}
