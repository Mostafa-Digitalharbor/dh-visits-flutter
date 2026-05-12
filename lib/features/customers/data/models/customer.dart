import 'package:equatable/equatable.dart';

class Customer extends Equatable {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final String? address;
  final String? phone;
  final String? mobile;
  final CustomerLastVisit? lastVisit;

  const Customer({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    this.phone,
    this.mobile,
    this.lastVisit,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: (json['id'] as num).toInt(),
        name: (json['name'] ?? '').toString(),
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        address: json['address']?.toString(),
        phone: json['phone']?.toString(),
        mobile: json['mobile']?.toString(),
        lastVisit: json['last_visit'] is Map
            ? CustomerLastVisit.fromJson(
                Map<String, dynamic>.from(json['last_visit']))
            : null,
      );

  @override
  List<Object?> get props => [id, name, latitude, longitude];
}

class CustomerLastVisit extends Equatable {
  final int id;
  final String? employeeName;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;

  const CustomerLastVisit({
    required this.id,
    this.employeeName,
    this.checkInTime,
    this.checkOutTime,
  });

  factory CustomerLastVisit.fromJson(Map<String, dynamic> json) =>
      CustomerLastVisit(
        id: (json['id'] as num).toInt(),
        employeeName: json['employee_name']?.toString(),
        checkInTime: json['check_in_time'] != null
            ? DateTime.tryParse(json['check_in_time'].toString())?.toLocal()
            : null,
        checkOutTime: json['check_out_time'] != null
            ? DateTime.tryParse(json['check_out_time'].toString())?.toLocal()
            : null,
      );

  @override
  List<Object?> get props => [id, employeeName, checkInTime, checkOutTime];
}
