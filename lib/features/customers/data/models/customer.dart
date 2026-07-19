import 'package:equatable/equatable.dart';

class Customer extends Equatable {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final String? address;
  final String? phone;
  final String? mobile;

  /// Whether this contact is a company (vs. an individual person).
  final bool isCompany;
  final String? email;

  /// `res.partner.function` — the person's job title.
  final String? jobPosition;
  final String? street;
  final String? city;
  final String? zip;
  final String? stateName;
  final String? countryName;

  /// The related/parent company name (`parent_id`), for individual contacts.
  final String? parentCompanyName;

  /// Tag names (`category_id`), resolved server-side.
  final List<String> categories;
  final String? website;

  /// Tax ID / VAT.
  final String? vat;

  final CustomerLastVisit? lastVisit;

  const Customer({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    this.phone,
    this.mobile,
    this.isCompany = false,
    this.email,
    this.jobPosition,
    this.street,
    this.city,
    this.zip,
    this.stateName,
    this.countryName,
    this.parentCompanyName,
    this.categories = const [],
    this.website,
    this.vat,
    this.lastVisit,
  });

  /// Whether we hold a real (non-zero) geo coordinate for this customer.
  bool get hasCoordinates => latitude != 0 && longitude != 0;

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: (json['id'] as num).toInt(),
        name: (json['name'] ?? '').toString(),
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        address: json['address']?.toString(),
        phone: json['phone']?.toString(),
        mobile: json['mobile']?.toString(),
        isCompany: json['is_company'] == true,
        email: json['email']?.toString(),
        jobPosition: json['job_position']?.toString(),
        street: json['street']?.toString(),
        city: json['city']?.toString(),
        zip: json['zip']?.toString(),
        stateName: json['state_name']?.toString(),
        countryName: json['country_name']?.toString(),
        parentCompanyName: json['parent_name']?.toString(),
        categories: json['categories'] is List
            ? (json['categories'] as List).map((e) => e.toString()).toList()
            : const [],
        website: json['website']?.toString(),
        vat: json['vat']?.toString(),
        lastVisit: json['last_visit'] is Map
            ? CustomerLastVisit.fromJson(
                Map<String, dynamic>.from(json['last_visit']))
            : null,
      );

  @override
  List<Object?> get props => [id, name, latitude, longitude, isCompany, email];
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
