// Locks in the shape of the signed-out entry flow: **server screen first**,
// login second, and a way back between them.
//
// Why a test and not a glance at the router: every rule here lives in one
// `redirect` closure whose branches differ only by *where the user came from*.
// Nothing on screen says which branch ran, so a well-meaning simplification
// ("unauthenticated → /login") reads as correct, passes every other test, and
// only shows up as the first screen of a fresh install being the wrong one —
// which is exactly what got build 1.0 (4) rejected from the App Store.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:location_gps/app/router.dart';
import 'package:location_gps/app/routes.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/core/api/api_client.dart';
import 'package:location_gps/core/config/server_config.dart';
import 'package:location_gps/core/config/server_config_cubit.dart';
import 'package:location_gps/core/config/server_config_repository.dart';
import 'package:location_gps/core/di/service_locator.dart';
import 'package:location_gps/core/settings/settings_cubit.dart';
import 'package:location_gps/core/settings/settings_repository.dart';
import 'package:location_gps/features/auth/bloc/auth_bloc.dart';
import 'package:location_gps/features/auth/data/auth_repository.dart';
import 'package:location_gps/features/auth/view/login_page.dart';
import 'package:location_gps/features/auth/view/splash_page.dart';
import 'package:location_gps/features/server_config/view/server_setup_page.dart';
import 'package:location_gps/l10n/generated/app_localizations.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepo implements AuthRepository {
  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

/// An auth bloc whose state the test drives directly — no `AuthStarted`, so it
/// stays in `unknown` (a cold start on the splash screen) until told otherwise.
class _TestAuthBloc extends AuthBloc {
  _TestAuthBloc() : super(repository: _FakeAuthRepo());

  void setState(AuthState state) => emit(state);
}

/// A server that has already been configured — the case the entry flow is
/// actually about. (An *unconfigured* one has always been gated to /setup.)
class _ConfiguredServerRepo implements ServerConfigRepository {
  @override
  ServerConfig read() => const ServerConfig(
        baseUrl: 'https://example.odoo.com',
        database: 'example-main-1',
      );

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _BlankServerRepo implements ServerConfigRepository {
  @override
  ServerConfig read() => ServerConfig.empty;

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

/// Only `updateBaseUrl` runs during construction; anything else would be a
/// network call this test has no business making.
class _FakeApiClient implements ApiClient {
  @override
  void updateBaseUrl(String baseUrl) {}

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

/// The path the router has settled on.
String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    // LoginPage reads the remembered identifier from the locator in initState.
    if (!sl.isRegistered<SettingsRepository>()) {
      sl.registerSingleton<SettingsRepository>(SettingsRepository(prefs: prefs));
    }
  });

  /// Boots the real router over stub blocs and returns it.
  ///
  /// The auth screens paint a photographic hero, and the test asset bundle
  /// cannot resolve it — those arrive through `FlutterError.onError` exactly
  /// like a layout bug would, so the collector separates the two: image
  /// failures are an artefact of the harness, anything else fails the test.
  Future<(GoRouter, _TestAuthBloc)> pumpApp(
    WidgetTester tester, {
    ServerConfigRepository? serverRepo,
  }) async {
    final authBloc = _TestAuthBloc();
    final serverConfig = ServerConfigCubit(
      repository: serverRepo ?? _ConfiguredServerRepo(),
      apiClient: _FakeApiClient(),
    );
    final router = buildRouter(authBloc, serverConfig);
    addTearDown(() {
      router.dispose();
      serverConfig.close();
      authBloc.close();
    });

    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<ServerConfigCubit>.value(value: serverConfig),
          // The hero's language / theme chips read this during build.
          BlocProvider<SettingsCubit>(
            create: (_) => SettingsCubit(repository: sl<SettingsRepository>()),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    await tester.pump();

    FlutterError.onError = previous;
    expect(
      errors
          .where((e) => e.library != 'image resource service')
          .map((e) => e.exceptionAsString())
          .toList(),
      isEmpty,
    );
    return (router, authBloc);
  }

  /// Lets a redirect + its fade transition settle. Not `pumpAndSettle`: the
  /// splash screen runs a pulse that never reports "no more frames".
  ///
  /// Errors are captured and asserted on the same terms as in [pumpApp] rather
  /// than merely silenced — a swallowed handler here would hide a screen that
  /// throws on build and still let the location assertion pass.
  Future<void> settle(WidgetTester tester) async {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    FlutterError.onError = previous;
    expect(
      errors
          .where((e) => e.library != 'image resource service')
          .map((e) => e.exceptionAsString())
          .toList(),
      isEmpty,
    );
  }

  testWidgets('a cold start opens on the server screen, not on login',
      (tester) async {
    final (router, authBloc) = await pumpApp(tester);

    // Session restore is still running.
    expect(find.byType(SplashPage), findsOneWidget);

    // …and finds nothing: the app is signed out, with a server already saved.
    authBloc.setState(const AuthState.unauthenticated());
    await settle(tester);

    expect(_location(router), AppRoutes.setup);
    expect(find.byType(ServerSetupPage), findsOneWidget);
  });

  testWidgets('an unconfigured server still gates straight to setup',
      (tester) async {
    final (router, authBloc) = await pumpApp(tester, serverRepo: _BlankServerRepo());
    authBloc.setState(const AuthState.unauthenticated());
    await settle(tester);

    expect(_location(router), AppRoutes.setup);
  });

  testWidgets('a session that ends mid-app goes to login, not back through setup',
      (tester) async {
    final (router, authBloc) = await pumpApp(tester);
    authBloc.setState(const AuthState.unauthenticated());
    await settle(tester);

    // The pair the redirect actually sees when someone signs out from their
    // profile tab (or a 401 lands mid-task): unauthenticated, at a location
    // that is not the splash. Navigating to one directly exercises that branch
    // without building the page, which the redirect intercepts anyway.
    router.go(AppRoutes.customers);
    await settle(tester);

    expect(_location(router), AppRoutes.login);
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets("login's back chip returns to the server screen", (tester) async {
    final (router, authBloc) = await pumpApp(tester);
    authBloc.setState(const AuthState.unauthenticated());
    await settle(tester);

    router.go(AppRoutes.login);
    await settle(tester);
    expect(find.byType(LoginPage), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await settle(tester);

    expect(_location(router), AppRoutes.setup);
    expect(find.byType(ServerSetupPage), findsOneWidget);
  });

  testWidgets('the system back gesture on login agrees with the chip',
      (tester) async {
    final (router, authBloc) = await pumpApp(tester);
    authBloc.setState(const AuthState.unauthenticated());
    await settle(tester);

    router.go(AppRoutes.login);
    await settle(tester);

    // What Android's back button delivers.
    await tester.binding.handlePopRoute();
    await settle(tester);

    expect(_location(router), AppRoutes.setup);
  });

  testWidgets('the server screen carries no back chip — it is the entry point',
      (tester) async {
    final (_, authBloc) = await pumpApp(tester);
    authBloc.setState(const AuthState.unauthenticated());
    await settle(tester);

    expect(find.byType(ServerSetupPage), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
  });

  // Both arrows carry `matchTextDirection`, so Flutter mirrors them itself: in
  // Arabic `arrow_back` renders pointing right and `arrow_forward` pointing
  // left, which is what those directions mean in RTL. Choosing the glyph by
  // `Directionality` on top of that — the obvious-looking "RTL fix" — cancels
  // the mirroring out and leaves both arrows pointing the wrong way. These two
  // expectations exist to fail that rewrite, since nothing else would.
  test('the framework, not the widget, mirrors the arrows', () {
    expect(Symbols.arrow_back.matchTextDirection, isTrue);
    expect(Symbols.arrow_forward.matchTextDirection, isTrue);
  });

  testWidgets('each arrow is the plain semantic glyph, never a hand-flipped one',
      (tester) async {
    final (router, authBloc) = await pumpApp(tester);
    authBloc.setState(const AuthState.unauthenticated());
    await settle(tester);

    // Setup's CTA advances to login.
    expect(find.byIcon(Symbols.arrow_forward), findsOneWidget);
    expect(find.byIcon(Symbols.arrow_back), findsNothing);

    router.go(AppRoutes.login);
    await settle(tester);

    // Login's chip goes back to setup.
    expect(find.byIcon(Symbols.arrow_back), findsOneWidget);
    expect(find.byIcon(Symbols.arrow_forward), findsNothing);
  });
}
