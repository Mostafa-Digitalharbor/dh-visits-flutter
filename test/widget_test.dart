import 'package:flutter_test/flutter_test.dart';

import 'package:location_gps/core/utils/distance.dart';

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
}
