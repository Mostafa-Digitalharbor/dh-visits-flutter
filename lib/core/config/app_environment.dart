import 'package:flutter/foundation.dart';

/// Build-time configuration sourced from `--dart-define` flags.
///
/// The app is **multi-tenant**: every company runs its own Odoo server, so the
/// backend URL and database are normally entered once by the user on the
/// server-setup screen and persisted via `ServerConfigRepository`. These
/// `--dart-define`s are only a seed for CI and automated builds.
///
/// Usage:
///   flutter run --dart-define=API_BASE_URL=https://odoo.example.com \
///               --dart-define=ODOO_DATABASE=prod_db_name
///
/// **A release binary never carries a company's URL or database name unless it
/// was explicitly passed at build time.** Debug builds behave the same by
/// default: they start blank and show the server-setup screen, exactly like a
/// customer's (or an App Store reviewer's) first launch. Opt back into the test
/// backend with `--dart-define=DEV_SEED_SERVER=true` — see [_devSeedServer].
class AppEnvironment {
  AppEnvironment._();

  // Dev-only seeds. Gated behind [_devSeedServer] + `kReleaseMode` below rather
  // than used as `defaultValue`, because a `defaultValue` is compiled into
  // *every* build — including a store release, which would then ship one
  // customer's server address to every other customer.
  static const String _devSeedBaseUrl =
      'https://thedigitalharbor-dh-visits-new.odoo.com';
  static const String _devSeedDatabase =
      'thedigitalharbor-dh-visits-new-main-35787218';

  /// Opt-in shortcut for local work: `flutter run --dart-define=DEV_SEED_SERVER=true`
  /// pre-fills the test backend so the setup screen is skipped.
  ///
  /// **Off by default on purpose.** While it was on, every debug run jumped
  /// straight to /login, so the first screen a real user sees was the one screen
  /// nobody on the team ever saw — and an App Store reviewer was blocked on it
  /// in build 1.0 (4) (guideline 2.1, "provide server address").
  static const bool _devSeedServer = bool.fromEnvironment('DEV_SEED_SERVER');

  static bool get _useDevSeed => _devSeedServer && !kReleaseMode;

  static const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _definedDatabase =
      String.fromEnvironment('ODOO_DATABASE');

  /// Build-time backend base URL fallback (no trailing slash), or `''` when
  /// none was supplied — in which case the app asks for it on the setup screen.
  static String get baseUrl => _definedBaseUrl.isNotEmpty
      ? _definedBaseUrl
      : (_useDevSeed ? _devSeedBaseUrl : '');

  /// Build-time Odoo database fallback, or `''` when none was supplied.
  static String get database => _definedDatabase.isNotEmpty
      ? _definedDatabase
      : (_useDevSeed ? _devSeedDatabase : '');

  /// The public OSRM demo server (OpenStreetMap data, like the map tiles).
  /// Development only: its usage policy rules out production traffic, it has
  /// no SLA, and it would receive employees' coordinates — see
  /// docs/WORKDAY_TRACKING.md "Road matching". Never used by a release build.
  static const String publicOsrmUrl = 'https://router.project-osrm.org';

  /// Public demo routing servers a release build refuses to talk to.
  static const Set<String> _publicDemoHosts = {
    'router.project-osrm.org',
    'routing.openstreetmap.de',
  };

  static const bool _mapMatchingDefined = bool.hasEnvironment('MAP_MATCHING_URL');
  static const String _definedMapMatchingUrl =
      String.fromEnvironment('MAP_MATCHING_URL');

  /// OSRM-compatible server used to match recorded routes to roads for
  /// display: `--dart-define=MAP_MATCHING_URL=https://osrm.example.com`.
  /// Empty means road matching is off and routes are drawn as recorded.
  ///
  /// A **release** build only ever uses a URL passed at build time — the
  /// company-controlled server — and never the public demo server, not even
  /// when it is passed explicitly. Debug and profile builds default to the
  /// public demo server so development works without infrastructure.
  static String get mapMatchingUrl => resolveMapMatchingUrl(
        defined: _mapMatchingDefined,
        value: _definedMapMatchingUrl,
        release: kReleaseMode,
      );

  @visibleForTesting
  static String resolveMapMatchingUrl({
    required bool defined,
    required String value,
    required bool release,
  }) {
    final url = value.trim();
    if (!release) return defined ? url : publicOsrmUrl;
    if (!defined || url.isEmpty) return '';
    final uri = Uri.tryParse(url);
    // HTTPS only (cleartext is blocked on both platforms anyway), and never a
    // public demo server: employee coordinates stay on company infrastructure.
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return '';
    if (isPublicDemoServer(url)) return '';
    return url;
  }

  static bool isPublicDemoServer(String url) =>
      _publicDemoHosts.contains(Uri.tryParse(url.trim())?.host.toLowerCase());

  /// Most GPS fixes the matching server accepts in one request
  /// (`--dart-define=MAP_MATCHING_MAX_POINTS=100` for a self-hosted server
  /// with a raised `--max-matching-size`). 0 = the matcher's default: 10 on
  /// the public demo server, 90 elsewhere.
  static const int mapMatchingMaxPoints =
      int.fromEnvironment('MAP_MATCHING_MAX_POINTS');

  /// OSRM profile the server was built with (`driving`, `foot`, ...).
  static const String mapMatchingProfile =
      String.fromEnvironment('MAP_MATCHING_PROFILE', defaultValue: 'driving');

  /// Build flavour name surfaced in logs / settings screen.
  static const String flavor = String.fromEnvironment(
    'APP_FLAVOR',
    defaultValue: 'dev',
  );

  static bool get isProduction => flavor == 'production';

  /// The Digital Harbor / Visits Sentry project.
  ///
  /// Baked into the source rather than injected, because a Sentry DSN is a
  /// **write-only client ingest key**. It is designed to ship inside the app
  /// binary — anyone who downloads the APK can read it out — so treating it as
  /// a secret buys nothing and costs the one thing that matters: a store build
  /// whose crash reporting was silently off because a CI secret was never set.
  /// That is not hypothetical; `--dart-define=SENTRY_DSN=` with an *empty*
  /// value beats a `defaultValue`, so a half-configured pipeline produced
  /// exactly that.
  ///
  /// Keep this in sync with `scripts/build_release.sh`, which is the local
  /// equivalent of the release workflow.
  static const String _releaseDsn =
      'https://e1c8ae84f3d415fa15d41ec6436c54b5@o4511426995617792.ingest.de.sentry.io/4511485485973584';

  static const String _definedSentryDsn = String.fromEnvironment('SENTRY_DSN');

  /// Sentry DSN for crash reporting, or `''` when Sentry should stay off.
  ///
  /// Resolution order:
  ///   1. `--dart-define=SENTRY_DSN=...` — point a build at a different Sentry
  ///      project (staging, a customer-specific org).
  ///   2. otherwise a **release** build always reports to [_releaseDsn]. A
  ///      store binary with no crash reporting is a silent regression nobody
  ///      notices until they need a stack trace and there isn't one.
  ///   3. otherwise (debug / profile) Sentry is off, so local runs don't spend
  ///      the free quota on errors a developer is already staring at.
  static String get sentryDsn {
    if (_definedSentryDsn.isNotEmpty) return _definedSentryDsn;
    return kReleaseMode ? _releaseDsn : '';
  }

  static bool get sentryEnabled => sentryDsn.isNotEmpty;

  /// The `environment` tag on every Sentry event.
  ///
  /// Derived rather than taken straight from [flavor] on purpose: a store
  /// binary is never "dev", and a CI job that passes `--dart-define=APP_FLAVOR=`
  /// with an *empty* secret would otherwise tag production crashes with an
  /// empty string. `String.fromEnvironment` only falls back to its
  /// `defaultValue` when the key is **absent** -- an empty value wins -- so the
  /// guard has to live here.
  static String get sentryEnvironment {
    if (!kReleaseMode) return 'development';
    return (flavor.isEmpty || flavor == 'dev') ? 'production' : flavor;
  }

  /// Sample rate for performance/transaction monitoring, expressed as a
  /// percentage (0--100). Default 10 keeps Sentry cost low in production;
  /// raise to 100 in staging to validate.
  static const int _sentryTracesPercent = int.fromEnvironment(
    'SENTRY_TRACES_PERCENT',
    defaultValue: 10,
  );

  static double get sentryTracesSampleRate => _sentryTracesPercent / 100.0;
}
