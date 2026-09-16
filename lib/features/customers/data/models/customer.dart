import 'package:equatable/equatable.dart';

import '../../../../core/api/odoo_parse.dart';

class Customer extends Equatable {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final String? address;
  final String? phone;

  /// A second number. Odoo 17+ merged `mobile` into `phone`, so the directory
  /// no longer reads it; kept for servers and callers that still supply one.
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

  /// The most recent visit that was started for this customer, if any.
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

  /// Whether we hold a real (non-zero, on-the-globe) coordinate for this
  /// customer. Odoo stores an unset float as `0.0`.
  bool get hasCoordinates =>
      latitude != 0 && longitude != 0 && isValidLatLng(latitude, longitude);

  /// Whether a visit to this customer is running right now.
  bool get hasActiveVisit => lastVisit?.isActive ?? false;

  /// Parses the shape `CustomersRepository` adapts a `res.partner` row into.
  ///
  /// Every reader is tolerant: Odoo serialises an unset field as `false`, so a
  /// bare `as num` cast throws on it and `?.toString()` renders the literal
  /// "false" as a phone number.
  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: odooInt(json['id']) ??
            (throw const FormatException('customer row without an id')),
        name: odooString(json['name']) ?? '',
        latitude: odooCoord(json['latitude']) ?? 0,
        longitude: odooCoord(json['longitude']) ?? 0,
        address: odooString(json['address']),
        phone: odooString(json['phone']),
        mobile: odooString(json['mobile']),
        isCompany: odooBool(json['is_company']),
        email: odooString(json['email']),
        jobPosition: odooString(json['job_position']),
        street: odooString(json['street']),
        city: odooString(json['city']),
        zip: odooString(json['zip']),
        stateName: odooString(json['state_name']),
        countryName: odooString(json['country_name']),
        parentCompanyName: odooString(json['parent_name']),
        categories:
            odooList(json['categories']).map(odooString).whereType<String>().toList(),
        website: odooString(json['website']),
        vat: odooString(json['vat']),
        lastVisit: switch (odooMap(json['last_visit'])) {
          final Map<String, dynamic> visit => CustomerLastVisit.fromJson(visit),
          null => null,
        },
      );

  /// This customer with [visit] as its last visit.
  Customer withLastVisit(CustomerLastVisit? visit) => Customer(
        id: id,
        name: name,
        latitude: latitude,
        longitude: longitude,
        address: address,
        phone: phone,
        mobile: mobile,
        isCompany: isCompany,
        email: email,
        jobPosition: jobPosition,
        street: street,
        city: city,
        zip: zip,
        stateName: stateName,
        countryName: countryName,
        parentCompanyName: parentCompanyName,
        categories: categories,
        website: website,
        vat: vat,
        lastVisit: visit,
      );

  // Every field: the list and detail screens compare states, and two customers
  // that differ only in their phone must not read as unchanged.
  @override
  List<Object?> get props => [
        id,
        name,
        latitude,
        longitude,
        address,
        phone,
        mobile,
        isCompany,
        email,
        jobPosition,
        street,
        city,
        zip,
        stateName,
        countryName,
        parentCompanyName,
        categories,
        website,
        vat,
        lastVisit,
      ];
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

  /// `dh.visit` fields [fromVisitRow] reads.
  static const visitFields = [
    'id',
    partnerField,
    'employee_id',
    startField,
    'end_datetime',
  ];
  static const partnerField = 'partner_id';
  static const startField = 'start_datetime';

  /// Started and not yet ended.
  bool get isActive => checkInTime != null && checkOutTime == null;

  factory CustomerLastVisit.fromJson(Map<String, dynamic> json) =>
      CustomerLastVisit(
        id: odooInt(json['id']) ??
            (throw const FormatException('last visit without an id')),
        employeeName: odooString(json['employee_name']),
        checkInTime: parseOdooUtc(json['check_in_time'])?.toLocal(),
        checkOutTime: parseOdooUtc(json['check_out_time'])?.toLocal(),
      );

  /// A `dh.visit` row read with [visitFields]. Times arrive as naive UTC.
  factory CustomerLastVisit.fromVisitRow(Map<String, dynamic> row) =>
      CustomerLastVisit(
        id: odooInt(row['id']) ??
            (throw const FormatException('visit row without an id')),
        employeeName: odooMany2one(row['employee_id']).name,
        checkInTime: parseOdooUtc(row[startField])?.toLocal(),
        checkOutTime: parseOdooUtc(row['end_datetime'])?.toLocal(),
      );

  @override
  List<Object?> get props => [id, employeeName, checkInTime, checkOutTime];
}
