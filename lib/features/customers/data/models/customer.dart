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

  /// Odoo serialises an unset field as `false` (a bool), never null. So a bare
  /// `as num` cast throws on it, and `json['phone']?.toString()` yields the
  /// literal string `"false"` — `false` is non-null, so `?.` does not
  /// short-circuit and the UI renders "false" as the customer's phone number.
  /// Both helpers below exist to stop that at the parse boundary.
  ///
  /// Today every caller goes through `CustomersRepository._adaptPartner`, which
  /// already sanitises each field, so this is belt-and-braces — but the moment
  /// anything feeds a raw Odoo row in, the unguarded version breaks visibly.
  static double _num0(dynamic raw) => raw is num ? raw.toDouble() : 0;
  static String? _str(dynamic raw) =>
      (raw is String && raw.isNotEmpty) ? raw : null;

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'] is num ? (json['id'] as num).toInt() : 0,
        name: _str(json['name']) ?? '',
        latitude: _num0(json['latitude']),
        longitude: _num0(json['longitude']),
        address: _str(json['address']),
        phone: _str(json['phone']),
        mobile: _str(json['mobile']),
        isCompany: json['is_company'] == true,
        email: _str(json['email']),
        jobPosition: _str(json['job_position']),
        street: _str(json['street']),
        city: _str(json['city']),
        zip: _str(json['zip']),
        stateName: _str(json['state_name']),
        countryName: _str(json['country_name']),
        parentCompanyName: _str(json['parent_name']),
        categories: json['categories'] is List
            ? (json['categories'] as List).map((e) => e.toString()).toList()
            : const [],
        website: _str(json['website']),
        vat: _str(json['vat']),
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
