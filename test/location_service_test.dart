// Locks down how a Start/End fix is chosen.
//
// The defect: `getCurrent` returned the first position the platform handed
// over. With GPS idle, Android's fused provider answers first with the
// position it remembers. On the emulator that was a fix from a visit minutes
// earlier, about 600 m away, and it became the new visit's start location.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location_gps/core/location/location_service.dart';

final _now = DateTime.utc(2026, 9, 17, 16, 25, 22);

Position _fix(
  double latitude, {
  Duration age = Duration.zero,
  double accuracy = 5,
}) =>
    Position(
      latitude: latitude,
      longitude: 46.675,
      timestamp: _now.subtract(age),
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

class _FakeGeolocator extends GeolocatorPlatform {
  late final StreamController<Position> positions = StreamController<Position>(
    onCancel: () => cancelled = true,
  );
  LocationSettings? settings;
  bool cancelled = false;

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    settings = locationSettings;
    return positions.stream;
  }
}

void main() {
  late _FakeGeolocator geo;
  late LocationService service;

  setUp(() {
    geo = _FakeGeolocator();
    service = LocationService(
      platform: geo,
      clock: () => _now,
      timeLimit: const Duration(milliseconds: 200),
    );
  });

  test(
    'a current, precise fix is taken at once and the stream is closed',
    () async {
      final result = service.getCurrent();
      geo.positions.add(_fix(24.7136));
      expect((await result).latitude, 24.7136);
      expect(geo.cancelled, isTrue);
    },
  );

  test('a fix a few seconds old is skipped for the live one after it',
      () async {
    final result = service.getCurrent();
    geo.positions
      ..add(_fix(24.7400, age: const Duration(seconds: 4)))
      ..add(_fix(24.7500));
    expect((await result).latitude, 24.7500);
  });

  test('a remembered fix is skipped for the live one after it', () async {
    final result = service.getCurrent();
    geo.positions
      ..add(_fix(24.7180, age: const Duration(minutes: 4)))
      ..add(_fix(24.7136));
    expect((await result).latitude, 24.7136);
  });

  test('a coarse fix is skipped for a precise one after it', () async {
    final result = service.getCurrent();
    geo.positions
      ..add(_fix(24.7180, accuracy: 100))
      ..add(_fix(24.7136, accuracy: 12));
    expect((await result).latitude, 24.7136);
  });

  test(
    'a wrong device clock does not block the fix: a newer one is live',
    () async {
      final skewed = LocationService(
        platform: geo,
        clock: () => _now.add(const Duration(hours: 3)),
        timeLimit: const Duration(seconds: 30),
      );
      final result = skewed.getCurrent();
      geo.positions
        ..add(_fix(24.7180, age: const Duration(seconds: 1)))
        ..add(_fix(24.7136));
      expect((await result).latitude, 24.7136);
    },
  );

  test('an unknown accuracy (reported as 0) counts as precise', () async {
    final result = service.getCurrent();
    geo.positions.add(_fix(24.7136, accuracy: 0));
    expect((await result).latitude, 24.7136);
  });

  group('when time runs out', () {
    test('a fresh coarse fix beats a precise stale one', () async {
      final result = service.getCurrent();
      geo.positions
        ..add(_fix(24.7180, age: const Duration(minutes: 4)))
        ..add(_fix(24.7136, accuracy: 80));
      expect((await result).latitude, 24.7136);
      expect(geo.cancelled, isTrue);
    });

    test('among equals, the newest wins', () async {
      final result = service.getCurrent();
      geo.positions
        ..add(_fix(24.7101, accuracy: 90, age: const Duration(seconds: 2)))
        ..add(_fix(24.7102, accuracy: 90))
        ..add(_fix(24.7103, accuracy: 90, age: const Duration(seconds: 1)));
      expect((await result).latitude, 24.7102);
    });

    test(
      'two remembered fixes in a row are not taken for a live stream',
      () async {
        final result = service.getCurrent();
        geo.positions
          ..add(_fix(24.7180, age: const Duration(minutes: 4)))
          ..add(_fix(24.7170, age: const Duration(minutes: 3)));
        final fix = await result;
        // Only picked because time ran out: the newer of two stale fixes.
        expect(fix.latitude, 24.7170);
        expect(geo.cancelled, isTrue);
      },
    );

    test('a stale fix is still better than none', () async {
      final result = service.getCurrent();
      geo.positions.add(_fix(24.7180, age: const Duration(minutes: 4)));
      expect((await result).latitude, 24.7180);
    });

    test('no fix at all is a timeout', () async {
      await expectLater(service.getCurrent(), throwsA(isA<TimeoutException>()));
      expect(geo.cancelled, isTrue);
    });
  });

  group('when the platform fails', () {
    test('before any fix, the error reaches the caller', () async {
      final result = service.getCurrent();
      geo.positions.addError(const LocationServiceDisabledException());
      await expectLater(
        result,
        throwsA(isA<LocationServiceDisabledException>()),
      );
    });

    test('after a usable fix, that fix is returned', () async {
      final result = service.getCurrent();
      geo.positions
        ..add(_fix(24.7136, accuracy: 80))
        ..addError(const LocationServiceDisabledException());
      expect((await result).latitude, 24.7136);
    });

    test('a stream that ends with nothing is a timeout', () async {
      final result = service.getCurrent();
      await geo.positions.close();
      await expectLater(result, throwsA(isA<TimeoutException>()));
    });
  });

  group('Android request', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('asks for a fix every second, so a skipped one costs little',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final result = service.getCurrent();
      geo.positions.add(_fix(24.7136));
      await result;
      final settings = geo.settings;
      expect(settings, isA<AndroidSettings>());
      expect(
        (settings! as AndroidSettings).intervalDuration,
        const Duration(seconds: 1),
      );
      expect(settings.accuracy, LocationAccuracy.high);
      expect(settings.distanceFilter, 0);
    });

    test('other platforms keep the plain settings', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final result = service.getCurrent();
      geo.positions.add(_fix(24.7136));
      await result;
      expect(geo.settings, isNot(isA<AndroidSettings>()));
    });
  });
}
