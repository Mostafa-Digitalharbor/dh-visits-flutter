// Locks down the Start/End location policy.
//
// The defect this guards against: `_location()` returned `(double,double)?`
// and folded four outcomes into `null`, which callers read as "no coordinates,
// carry on". So denying permission — or *cancelling the mock-GPS warning* —
// started the visit anyway with no location recorded and no mock flag, making
// Cancel the best move available to someone spoofing their position.
//
// The type-level half of the fix is asserted by the compiler:
// `VisitDetailCubit.start` now takes `required double latitude/longitude`, so
// a GPS-less start no longer type-checks. These tests cover the rest — that
// each failure mode stays distinguishable rather than collapsing.
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/core/location/location_outcome.dart';

void main() {
  group('LocationOutcome', () {
    test('a cancelled mock warning is not a position', () {
      // The heart of it: Cancelled must never be mistaken for "proceed".
      const outcome = LocationCancelled();
      expect(outcome, isNot(isA<LocationOk>()));
    });

    test('each failure mode stays distinguishable', () {
      // They used to be one indistinguishable `null`; the caller must be able
      // to tell "user aborted" from "permission denied" from "no fix" to show
      // the right message — or stay silent.
      const outcomes = <LocationOutcome>[
        LocationPermissionDenied(),
        LocationUnavailable(),
        LocationCancelled(),
        LocationOk(latitude: 30.0444, longitude: 31.2357),
      ];
      expect(outcomes.whereType<LocationOk>(), hasLength(1));
      expect(outcomes.whereType<LocationPermissionDenied>(), hasLength(1));
      expect(outcomes.whereType<LocationUnavailable>(), hasLength(1));
      expect(outcomes.whereType<LocationCancelled>(), hasLength(1));
    });

    test('an exhaustive switch handles every case', () {
      // A sealed hierarchy makes this switch exhaustive at compile time, so a
      // future case can't silently fall through to "start without GPS".
      String describe(LocationOutcome o) => switch (o) {
            LocationOk() => 'ok',
            LocationPermissionDenied() => 'denied',
            LocationUnavailable() => 'unavailable',
            LocationCancelled() => 'cancelled',
          };

      expect(describe(const LocationOk(latitude: 1, longitude: 2)), 'ok');
      expect(describe(const LocationPermissionDenied()), 'denied');
      expect(describe(const LocationUnavailable()), 'unavailable');
      expect(describe(const LocationCancelled()), 'cancelled');
    });

    test('the mock flag rides along with the position', () {
      // isMocked used to exist only as a local in the widget and a Sentry
      // message — never on a value the workflow could record.
      const spoofed =
          LocationOk(latitude: 30.0, longitude: 31.0, isMocked: true);
      const real = LocationOk(latitude: 30.0, longitude: 31.0);
      expect(spoofed.isMocked, isTrue);
      expect(real.isMocked, isFalse);
    });

    test('LocationUnavailable carries the cause for diagnosis', () {
      // getCurrent() throws on its 10s timeout; that used to escape uncaught
      // and make the Start button appear to do nothing at all.
      final timeout = LocationUnavailable(Exception('TimeoutException'));
      expect(timeout.error, isNotNull);
    });
  });
}
