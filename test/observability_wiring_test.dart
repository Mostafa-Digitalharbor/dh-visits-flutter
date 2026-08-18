// Locks down the crash-reporting wiring, because every failure mode here is
// silent: the app runs perfectly, ships, and simply never tells you it crashed.
// Nothing on screen and nothing in a build log distinguishes "Sentry is on"
// from "Sentry was disabled by an empty --dart-define three weeks ago".
//
// These tests run under `flutter test`, which is a DEBUG build, so
// `kReleaseMode` is false here. That constrains what can be asserted directly
// (the release-mode branch of `sentryDsn` cannot be exercised) -- so the tests
// below check the two things that *are* observable and that actually broke:
// the debug default, and the noise filter that decides what reaches Sentry.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/core/api/api_exceptions.dart';
import 'package:location_gps/core/config/app_environment.dart';
import 'package:location_gps/core/observability/sentry_noise_filter.dart';

void main() {
  group('Sentry configuration', () {
    test('a debug build reports nothing', () {
      // The free quota is small and a developer running the app is already
      // looking at the error in the console.
      expect(AppEnvironment.sentryDsn, isEmpty);
      expect(AppEnvironment.sentryEnabled, isFalse);
    });

    test('a debug build is tagged development, never production', () {
      // Getting this backwards poisons the production error rate with a
      // developer's deliberate experiments.
      expect(AppEnvironment.sentryEnvironment, 'development');
    });

    test('the traces sample rate is a fraction, not a percentage', () {
      // Sentry takes 0.0-1.0. Handing it 10 instead of 0.1 samples every
      // transaction and burns the quota in hours.
      expect(AppEnvironment.sentryTracesSampleRate, inInclusiveRange(0.0, 1.0));
    });
  });

  group('isSentryNoise drops environmental failures', () {
    test('offline and timeout', () {
      expect(isSentryNoise(ApiException(code: ApiErrorCode.network)), isTrue);
      expect(isSentryNoise(ApiException(code: ApiErrorCode.timeout)), isTrue);
    });

    test('an expired session is not a defect', () {
      expect(isSentryNoise(ApiException(code: ApiErrorCode.unauthorized)), isTrue);
      expect(
        isSentryNoise(ApiException(code: ApiErrorCode.sessionRestoreFailed)),
        isTrue,
      );
    });

    test('a rep who denied location permission is not a crash', () {
      expect(
        isSentryNoise(ApiException(code: ApiErrorCode.locationPermission)),
        isTrue,
      );
    });

    test('raw 4xx from dio', () {
      expect(isSentryNoise(_dioStatus(403)), isTrue);
      expect(isSentryNoise(_dioStatus(404)), isTrue);
      expect(isSentryNoise(_dioStatus(422)), isTrue);
    });

    test('dio transport failures', () {
      for (final type in [
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.badCertificate,
        DioExceptionType.cancel,
      ]) {
        expect(
          isSentryNoise(DioException(requestOptions: _req, type: type)),
          isTrue,
          reason: '$type should be filtered',
        );
      }
    });
  });

  group('isSentryNoise keeps the failures worth waking up for', () {
    test('the server really did break', () {
      // A 5xx is the backend's bug or ours. Filtering it would hide the single
      // most actionable signal this app produces.
      expect(isSentryNoise(ApiException(code: ApiErrorCode.server)), isFalse);
      expect(isSentryNoise(_dioStatus(500)), isFalse);
      expect(isSentryNoise(_dioStatus(502)), isFalse);
    });

    test('an unmapped error shape', () {
      // `unknown` means the response did not match anything ApiClient knows
      // how to read -- which is precisely the interesting case.
      expect(isSentryNoise(ApiException(code: ApiErrorCode.unknown)), isFalse);
    });

    test('an ordinary programming error', () {
      expect(isSentryNoise(TypeError()), isFalse);
      expect(isSentryNoise(StateError('bad state')), isFalse);
      expect(isSentryNoise(ArgumentError('nope')), isFalse);
    });

    test('null is not noise, it is nothing', () {
      expect(isSentryNoise(null), isFalse);
    });
  });

  test('every ApiErrorCode has an explicit verdict', () {
    // The switch inside isSentryNoise is exhaustive, so a new code added to
    // the enum is a compile error rather than a silent `false`. This test just
    // proves the whole enum can be walked without throwing.
    for (final code in ApiErrorCode.values) {
      expect(
        () => isSentryNoise(ApiException(code: code)),
        returnsNormally,
        reason: '$code has no verdict',
      );
    }
  });
}

final _req = RequestOptions(path: '/api/visit/list');

DioException _dioStatus(int status) => DioException(
      requestOptions: _req,
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(requestOptions: _req, statusCode: status),
    );
