// Release builds must never send employee coordinates to a public demo
// routing server: road matching there is either the company-controlled URL
// passed at build time, or off (routes drawn as recorded GPS).
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/core/config/app_environment.dart';

void main() {
  String resolve({bool defined = false, String value = '', required bool release}) =>
      AppEnvironment.resolveMapMatchingUrl(
          defined: defined, value: value, release: release);

  group('release build', () {
    test('without MAP_MATCHING_URL road matching is off, not the demo server', () {
      expect(resolve(release: true), '');
    });

    test('uses the company server passed at build time', () {
      expect(
        resolve(defined: true, value: ' https://osrm.digitalharbor.example ', release: true),
        'https://osrm.digitalharbor.example',
      );
    });

    test('refuses the public demo servers even when passed explicitly', () {
      for (final url in [
        'https://router.project-osrm.org',
        'https://ROUTER.project-osrm.org/',
        'https://routing.openstreetmap.de/routed-car',
      ]) {
        expect(resolve(defined: true, value: url, release: true), '', reason: url);
      }
    });

    test('refuses cleartext and malformed URLs', () {
      expect(resolve(defined: true, value: 'http://10.0.0.5:5000', release: true), '');
      expect(resolve(defined: true, value: 'osrm.internal', release: true), '');
    });

    test('an explicitly empty URL keeps matching off', () {
      expect(resolve(defined: true, value: '', release: true), '');
    });
  });

  group('debug / profile build', () {
    test('defaults to the public demo server for development', () {
      expect(resolve(release: false), AppEnvironment.publicOsrmUrl);
      expect(AppEnvironment.isPublicDemoServer(AppEnvironment.publicOsrmUrl), isTrue);
    });

    test('an explicit URL wins, and empty turns matching off', () {
      expect(resolve(defined: true, value: 'http://10.0.2.2:5000', release: false),
          'http://10.0.2.2:5000');
      expect(resolve(defined: true, value: '', release: false), '');
    });
  });
}
