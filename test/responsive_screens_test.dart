// Renders the manager Dashboard, Analytics and the Visits list across the
// viewport / language / font-scale matrix the app actually ships into, and
// fails if anything overflows.
//
// This matters more than it looks. A `RenderFlex overflow` is a **debug-only**
// assertion: in a profile or release build the content is silently clipped, so
// driving the real APK on an emulator cannot detect it — a truncated KPI number
// or a cut-off Arabic label just looks like the design. The test binding, which
// runs in debug, records the overflow in `takeException()`, so these are the
// only place the app is genuinely checked for it.
//
// The matrix is chosen from the failure modes, not for coverage's sake:
//   * 320×640  — the smallest phone still in the field, and the width the KPI
//                grid's aspect-ratio maths is most likely to get wrong.
//   * 720×360  — landscape, where a fixed-height header eats the whole body.
//   * 800×1280 — a tablet, where `isTablet` widens paddings.
//   * ar + en  — Arabic runs materially longer, and RTL mirrors the layout.
//   * 1.25×    — the app's own text-scale ceiling (see app.dart).
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/features/analytics/view/analytics_page.dart';
import 'package:location_gps/features/auth/bloc/auth_bloc.dart';
import 'package:location_gps/features/auth/data/auth_repository.dart';
import 'package:location_gps/features/auth/data/models/user.dart';
import 'package:location_gps/features/customers/bloc/customers_bloc.dart';
import 'package:location_gps/features/customers/data/customers_repository.dart';
import 'package:location_gps/features/customers/data/models/customer.dart';
import 'package:location_gps/features/customers/view/customers_list_page.dart';
import 'package:location_gps/features/dashboard/view/dashboard_page.dart';
import 'package:location_gps/features/review/view/review_page.dart';
import 'package:location_gps/features/route/view/route_page.dart';
import 'package:location_gps/features/profile/view/profile_page.dart';
import 'package:location_gps/core/api/api_client.dart';
import 'package:location_gps/core/config/server_config.dart';
import 'package:location_gps/core/config/server_config_cubit.dart';
import 'package:location_gps/core/config/server_config_repository.dart';
import 'package:location_gps/core/di/service_locator.dart';
import 'package:location_gps/core/network/connectivity_status.dart';
import 'package:location_gps/core/network/pending_actions_queue.dart';
import 'package:location_gps/core/settings/settings_cubit.dart';
import 'package:location_gps/core/settings/settings_repository.dart';
import 'package:location_gps/shared/bloc/searchable_list_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:location_gps/features/visits/bloc/visits_list_bloc.dart';
import 'package:location_gps/features/visits/data/models/visit.dart';
import 'package:location_gps/features/visits/data/visits_repository.dart';
import 'package:location_gps/features/visits/view/visits_list_page.dart';
import 'package:location_gps/l10n/generated/app_localizations.dart';

class _FakeVisitsRepo implements VisitsRepository {
  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _FakeAuthRepo implements AuthRepository {
  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _FakeCustomersRepo implements CustomersRepository {
  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

/// An auth bloc parked in `authenticated` without touching the network.
class _StubAuthBloc extends AuthBloc {
  _StubAuthBloc(AuthUser user) : super(repository: _FakeAuthRepo()) {
    emit(AuthState.authenticated(user));
  }
}

/// A list bloc holding [items] in `success`, so the pages render real content
/// rather than a skeleton.
class _StubListBloc extends VisitsListBloc {
  _StubListBloc(List<Visit> items) : super(repository: _FakeVisitsRepo()) {
    emit(VisitsListState(status: VisitsListStatus.success, items: items));
  }
}

/// The review queue builds its own pending-scoped bloc and asks it to load.
/// This one keeps its seeded items and ignores the request — the fake
/// repository has nothing to answer with.
class _SeededReviewBloc extends _StubListBloc {
  _SeededReviewBloc(super.items);

  @override
  void add(VisitsListEvent event) {}
}

class _FakeServerConfigRepo implements ServerConfigRepository {
  @override
  ServerConfig read() => const ServerConfig(
        baseUrl: 'https://thedigitalharbor-dh-visits-new.odoo.com',
        database: 'thedigitalharbor-dh-visits-new-main-35787218',
      );

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

/// Only `updateBaseUrl` is reached during construction; everything else on the
/// client would be a network call this test has no business making.
class _FakeApiClient implements ApiClient {
  @override
  void updateBaseUrl(String baseUrl) {}

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

/// Same idea for the customer list. `ListLoadRequested` is fired from the
/// page's `initState`, so the loader would run against the fake repo — the
/// event handler is overridden to a no-op and the seeded state left standing.
class _StubCustomersBloc extends CustomersBloc {
  _StubCustomersBloc(List<Customer> items)
      : super(repository: _FakeCustomersRepo()) {
    emit(CustomersState(status: ListStatus.success, items: items));
  }

  @override
  void add(SearchableListEvent event) {}
}

const _manager = AuthUser(
  uid: 2,
  username: 'mona@test.com',
  employeeName: 'منى عادل عبد الرحمن الشمري',
  employeeId: 4,
  isAdmin: true,
  isManager: true,
);

/// Long Odoo-shaped names — the values that actually break these layouts.
const _longCustomer = 'شركة الخليج للمقاولات والاستثمار العقاري المحدودة';
const _longEmployee = 'عبد الرحمن بن محمد بن عبد الله السبيعي';

List<Visit> _seed() {
  final now = DateTime.now();
  return [
    for (var i = 0; i < 24; i++)
      Visit(
        id: i + 1,
        name: 'VIS/2026/${(i + 1).toString().padLeft(5, '0')}',
        partnerName: i.isEven ? _longCustomer : 'Acme Corp',
        employeeName: i % 3 == 0 ? _longEmployee : 'Sam Sales',
        purpose: 'زيارة متابعة لمناقشة تفاصيل العقد والجدول الزمني للتسليم',
        // A spread across today / this week / last week so every window and
        // every KPI bucket has something in it.
        scheduledDatetime: now.subtract(Duration(days: i % 14)),
        startDatetime: i % 3 == 0 ? now.subtract(Duration(days: i % 14)) : null,
        endDatetime: i % 3 == 0
            ? now.subtract(Duration(days: i % 14)).add(const Duration(hours: 2))
            : null,
        startLat: i % 3 == 0 ? 24.7 + i * 0.01 : null,
        startLng: i % 3 == 0 ? 46.6 + i * 0.01 : null,
        state: switch (i % 5) {
          0 => VisitState.done,
          1 => VisitState.submitted,
          2 => VisitState.approved,
          3 => VisitState.inProgress,
          _ => VisitState.draft,
        },
        isEscalated: i % 7 == 0,
      ),
  ];
}

/// Customers carrying the values that break the list card: a long Arabic
/// company name, a full address, a phone, tags, and a last visit — both still
/// open (the "active" badge) and closed (the relative-time badge).
List<Customer> _seedCustomers() {
  final now = DateTime.now();
  return [
    for (var i = 0; i < 20; i++)
      Customer(
        id: i + 1,
        name: i.isEven ? _longCustomer : 'Acme Corp',
        latitude: 24.7 + i * 0.01,
        longitude: 46.6 + i * 0.01,
        address: 'طريق الملك عبد العزيز، حي الملقا، الرياض ١٢٤٧٣، السعودية',
        phone: '+966 55 123 4567',
        isCompany: i.isEven,
        jobPosition: 'مدير المشتريات والعقود',
        categories: const ['عميل ذهبي', 'قطاع حكومي'],
        lastVisit: i % 3 == 0
            ? null
            : CustomerLastVisit(
                id: i,
                employeeName: i % 4 == 0 ? _longEmployee : 'Sam Sales',
                checkInTime: now.subtract(Duration(hours: i + 1)),
                // Every third one still open, so the "active" branch of the
                // badge is exercised as well as the relative-time branch.
                checkOutTime: i % 3 == 1
                    ? null
                    : now.subtract(Duration(minutes: i * 10)),
              ),
      ),
  ];
}

typedef _Viewport = ({String name, Size size});

const _viewports = <_Viewport>[
  (name: 'small phone 320x640', size: Size(320, 640)),
  (name: 'landscape 720x360', size: Size(720, 360)),
  (name: 'tablet 800x1280', size: Size(800, 1280)),
];

/// Renders [page] and returns every layout error Flutter reported.
///
/// The dashboard hosts a live OSM map, and the test sandbox has no network, so
/// each tile fetch reports a `ClientException` through the same channel as a
/// layout error. Those are an artefact of the harness, not of the app, so the
/// image-resource library is filtered out — everything else, overflow included,
/// is returned and asserted on.
Future<List<FlutterErrorDetails>> _layoutErrors(
  WidgetTester tester,
  Widget page, {
  required Size size,
  required Locale locale,
  required double textScale,
  required List<Visit> items,
  List<Customer> customers = const [],
  // Tab bodies (Dashboard, Analytics, the two lists) are hosted by the shell's
  // Scaffold and need one supplied here. Full pages (Route, Review) build their
  // own, and nesting them changes the very constraints this test measures —
  // which is how a 38px overflow on Review hid behind an unrelated async
  // failure the first time it was covered.
  bool wrapInScaffold = true,
}) async {
  // The handler is restored before this returns, not in a `tearDown`. That
  // ordering is load-bearing: the caller's `expect` runs immediately after, and
  // a failing `expect` throws a `TestFailure` — which, with our collector still
  // installed in place of the binding's, escapes into the zone as an uncaught
  // error. The binding then trips its own
  // `'_pendingExceptionDetails != null': A test overrode FlutterError.onError`
  // assertion and prints *that* instead of the overflow, then hangs until the
  // 10-minute timeout. A passing run looks identical either way; only a
  // regression tells them apart, which is the run that has to be readable.
  final collected = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = collected.add;

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  // Resetting the view relays the tree out at the default size. Anything that
  // overflows only at that size is an artefact of the teardown, not of the
  // screen under test, so it is swallowed rather than failing the next test.
  addTearDown(() {
    final active = FlutterError.onError;
    FlutterError.onError = (_) {};
    tester.view.reset();
    FlutterError.onError = active;
  });

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => _StubAuthBloc(_manager)),
        BlocProvider<VisitsListBloc>(create: (_) => _StubListBloc(items)),
        BlocProvider<CustomersBloc>(
            create: (_) => _StubCustomersBloc(customers)),
        BlocProvider<SettingsCubit>(
            create: (_) => SettingsCubit(repository: settingsRepo!)),
        BlocProvider<ServerConfigCubit>(
            create: (_) => ServerConfigCubit(
                  repository: _FakeServerConfigRepo(),
                  apiClient: _FakeApiClient(),
                )),
      ],
      child: MaterialApp(
        // The real theme, not the default: these pages read semantic tokens
        // through `context.x`, which resolves the `AppX` ThemeExtension and
        // asserts if it is absent.
        theme: AppTheme.light(),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: wrapInScaffold ? Scaffold(body: page) : page,
      ),
    ),
  );
  // Let the count-up and chart tweens run, without pumpAndSettle — the pages
  // host an AmbientPulse, which by design never settles into "no more frames"
  // for good (it wakes again after its rest).
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pump(const Duration(milliseconds: 900));

  FlutterError.onError = previous;

  return collected
      .where((e) => e.library != 'image resource service')
      .toList();
}

/// Fails with the overflow text itself, so a regression names the widget.
void _expectNoLayoutErrors(List<FlutterErrorDetails> errors) {
  expect(
    errors.map((e) => e.exceptionAsString()).toList(),
    isEmpty,
  );
}

/// Built once in `setUpAll` against mocked prefs. `SettingsCubit` reads the
/// stored theme/locale in its constructor, so it needs a real repository
/// rather than a `noSuchMethod` fake.
SettingsRepository? settingsRepo;

void main() {
  setUpAll(() async {
    initializeDateFormatting();
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    settingsRepo = SettingsRepository(prefs: prefs);
    // The settings "last sync" row resolves the queue straight out of the
    // service locator during build, so the locator has to be populated even
    // though this test never syncs anything.
    if (!sl.isRegistered<PendingActionsQueue>()) {
      sl.registerSingleton<PendingActionsQueue>(PendingActionsQueue(
        prefs: prefs,
        repository: _FakeVisitsRepo(),
        connectivity: ConnectivityStatus(),
      ));
    }
    // The settings screen reads the build version from platform metadata,
    // which has no implementation under the test binding.
    PackageInfo.setMockInitialValues(
      appName: 'Visits',
      packageName: 'net.digitalharbor.visits',
      version: '1.0.0',
      buildNumber: '5',
      buildSignature: '',
    );
  });

  final items = _seed();
  final customers = _seedCustomers();

  for (final vp in _viewports) {
    for (final locale in const [Locale('ar'), Locale('en')]) {
      for (final scale in const [1.0, 1.25]) {
        final tag = '${vp.name} · ${locale.languageCode} · ${scale}x';

        testWidgets('Dashboard fits — $tag', (tester) async {
          _expectNoLayoutErrors(await _layoutErrors(
              tester, const DashboardPage(),
              size: vp.size, locale: locale, textScale: scale, items: items));
        });

        testWidgets('Analytics fits — $tag', (tester) async {
          _expectNoLayoutErrors(await _layoutErrors(
              tester, const AnalyticsPage(),
              size: vp.size, locale: locale, textScale: scale, items: items));
        });

        // The list is the screen a rep lives in all day, and the one that
        // renders the longest Odoo-shaped strings (customer + project +
        // employee on one card). The file header always claimed it was
        // covered; it wasn't.
        testWidgets('Visits list fits — $tag', (tester) async {
          _expectNoLayoutErrors(await _layoutErrors(
              tester, const VisitsListPage(),
              size: vp.size, locale: locale, textScale: scale, items: items));
        });

        // The manager's other everyday tab. Its card packs a name, an address,
        // a phone, a "last visit" badge and a chevron onto one line — and the
        // badge sits in the unbounded slot of that row, where a widget that
        // asks its parent to flex throws rather than merely overflowing.
        testWidgets('Customers list fits — $tag', (tester) async {
          _expectNoLayoutErrors(await _layoutErrors(
              tester, const CustomersListPage(),
              size: vp.size,
              locale: locale,
              textScale: scale,
              items: items,
              customers: customers));
        });

        // Route and Review read the same bloc as the visits list but lay it out
        // far more densely — a timeline row and a per-day comparison table,
        // both packing numbers and Arabic labels onto one line.
        testWidgets('Route fits — $tag', (tester) async {
          _expectNoLayoutErrors(await _layoutErrors(tester, const RoutePage(),
              size: vp.size,
              locale: locale,
              textScale: scale,
              items: items,
              wrapInScaffold: false));
        });

        testWidgets('Review fits — $tag', (tester) async {
          _expectNoLayoutErrors(await _layoutErrors(tester,
              ReviewPage(createBloc: () => _SeededReviewBloc(items)),
              size: vp.size,
              locale: locale,
              textScale: scale,
              items: items,
              wrapInScaffold: false));
        });

        // Profile is the densest single column in the app: an identity card, a
        // switch row, and two radio groups whose labels are the longest
        // translated strings in the ARBs.
        testWidgets('Profile fits — $tag', (tester) async {
          _expectNoLayoutErrors(await _layoutErrors(tester, const ProfileView(),
              size: vp.size, locale: locale, textScale: scale, items: items));
        });
      }
    }
  }

  group('degenerate data', () {
    // A brand-new deployment: every screen must render zeros without dividing
    // by zero or overflowing an empty chart.
    testWidgets('Dashboard renders an empty team', (tester) async {
      _expectNoLayoutErrors(await _layoutErrors(tester, const DashboardPage(),
          size: const Size(320, 640),
          locale: const Locale('ar'),
          textScale: 1.25,
          items: const []));
    });

    testWidgets('Analytics renders an empty team', (tester) async {
      _expectNoLayoutErrors(await _layoutErrors(tester, const AnalyticsPage(),
          size: const Size(320, 640),
          locale: const Locale('ar'),
          textScale: 1.25,
          items: const []));
    });

    testWidgets('four-digit KPI counts still fit the tile', (tester) async {
      // The KPI tiles size their own aspect ratio; a busy region with
      // thousands of visits is where that arithmetic gets tested for real.
      final many = [
        for (var i = 0; i < 1200; i++)
          Visit(
            id: i + 1,
            partnerName: _longCustomer,
            employeeName: _longEmployee,
            scheduledDatetime: DateTime.now(),
            state: VisitState.submitted,
          ),
      ];
      _expectNoLayoutErrors(await _layoutErrors(tester, const DashboardPage(),
          size: const Size(320, 640),
          locale: const Locale('ar'),
          textScale: 1.25,
          items: many));
    });
  });
}
