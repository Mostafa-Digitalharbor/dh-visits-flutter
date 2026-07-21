import 'package:flutter_test/flutter_test.dart';

import 'package:location_gps/core/utils/distance.dart';
import 'package:location_gps/features/visits/data/models/visit.dart';

void main() {
  test('haversine distance is ~0 for identical points', () {
    final d = haversineMeters(30.044, 31.235, 30.044, 31.235);
    expect(d, lessThan(0.01));
  });

  test('haversine distance approximates 10m correctly', () {
    // ~10m east at Cairo latitude
    final d = haversineMeters(30.044420, 31.235712, 30.044420, 31.235816);
    expect(d, greaterThan(8));
    expect(d, lessThan(12));
  });

  group('Visit.hasCustomerLocation', () {
    // Odoo leaves `latitude`/`longitude` at 0.0 on every visit that was never
    // geocoded — which is all of them on the live server. Treating that as a
    // real fix put the Route map's stops in the Gulf of Guinea and had it
    // compute the drive between them.
    test('0,0 is treated as absent, not as a location', () {
      const v = Visit(id: 1, name: 'V-1', latitude: 0, longitude: 0);
      expect(v.hasCustomerLocation, isFalse);
    });

    test('a missing coordinate is absent', () {
      expect(const Visit(id: 1, name: 'V-1').hasCustomerLocation, isFalse);
      expect(
        const Visit(id: 1, name: 'V-1', latitude: 24.7).hasCustomerLocation,
        isFalse,
      );
    });

    test('a real coordinate is present', () {
      const v = Visit(id: 1, name: 'V-1', latitude: 24.7136, longitude: 46.6753);
      expect(v.hasCustomerLocation, isTrue);
    });

    test('a real coordinate on one axis with 0 on the other is still present', () {
      // 0 latitude is a valid place (the equator); only the 0,0 pair is the
      // "never set" sentinel.
      const v = Visit(id: 1, name: 'V-1', latitude: 0, longitude: 46.6753);
      expect(v.hasCustomerLocation, isTrue);
    });
  });
}
