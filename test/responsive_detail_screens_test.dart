// Overflow coverage for the screens `responsive_screens_test.dart` does not
// reach.
//
// That file covers the seven screens hosted by the home shell (Dashboard,
// Analytics, the two lists, Route, Review, Settings). Everything a user reaches
// by *pushing* — the auth pair, the notification feed, and the three visit /
// customer detail screens — was never rendered under test at all, which is a
// real gap rather than a cosmetic one:
//
//   * A `RenderFlex overflow` is a debug-only assertion. Release and profile
//     builds clip silently, so driving the APK on a device cannot find one.
//     These tests are the only place the app is genuinely checked.
//   * The uncovered screens are the *form*-shaped ones, and forms are where
//     fixed-height rows meet the OS text scale — precisely the combination
//     that clips.
//   * They also carry the longest translated strings in the ARBs (the
//     "forgot password" body, the server-setup helper text, the workflow
//     state labels), and Arabic runs materially longer than English.
//
// Same matrix and same rationale as the sibling file: smallest phone still in
// the field, landscape (where a fixed-height header eats the whole body), a
// tablet, both languages, and the app's own 1.25× text-scale ceiling.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
import 'package:location_gps/features/auth/data/models/user.dart';
import 'package:location_gps/features/auth/view/login_page.dart';
import 'package:location_gps/features/customers/data/customers_repository.dart';
import 'package:location_gps/features/customers/data/models/customer.dart';
import 'package:location_gps/features/customers/view/customer_detail_page.dart';
import 'package:location_gps/features/notifications/view/notifications_page.dart';
import 'package:location_gps/features/server_config/view/server_setup_page.dart';
import 'package:location_gps/features/visits/bloc/visits_list_bloc.dart';
import 'package:location_gps/features/visits/data/models/visit.dart';
import 'package:location_gps/features/visits/data/models/visit_activity.dart';
import 'package:location_gps/features/visits/data/models/visit_attachment.dart';
import 'package:location_gps/features/visits/data/models/visit_participant.dart';
import 'package:location_gps/features/visits/data/visits_repository.dart';
import 'package:location_gps/features/visits/view/create_visit_page.dart';
import 'package:location_gps/features/visits/view/visit_detail_page.dart';
import 'package:location_gps/l10n/generated/app_localizations.dart';

// ─── Fixtures ────────────────────────────────────────────────────────────────
// Odoo-shaped values, not placeholder ones. A layout that survives "Acme Corp"
// and fails on a real Saudi company name has not been tested.

const _longCustomer = 'شركة الخليج للمقاولات والاستثمار العقاري المحدودة';
const _longEmployee = 'عبد الرحمن بن محمد بن عبد الله السبيعي';
const _longPurpose =
    'زيارة متابعة لمناقشة تفاصيل العقد والجدول الزمني للتسليم ومراجعة '
    'الملاحظات الفنية الواردة من فريق التنفيذ';

const _manager = AuthUser(
  uid: 2,
  username: 'mona@test.com',
  employeeName: 'منى عادل عبد الرحمن الشمري',
  employeeId: 4,
  isAdmin: true,
  isManager: true,
);

/// A visit with *every* optional section populated, because the detail page
/// renders each one conditionally — a visit with nulls exercises none of them.
Visit _richVisit() {
  final now = DateTime.now();
  return Visit(
    id: 1,
    name: 'VIS/2026/00042',
    partnerName: _longCustomer,
    employeeName: _longEmployee,
    projectName: 'مشروع تطوير الواجهة البحرية — المرحلة الثانية',
    directManagerName: _longEmployee,
    higherManagerName: 'منى عادل عبد الرحمن الشمري',
    purpose: _longPurpose,
    location: 'طريق الملك عبد العزيز، حي الملقا، الرياض ١٢٤٧٣، السعودية',
    outcome: 'تم الاتفاق على تسليم الدفعة الأولى خلال أسبوعين',
    scheduledDatetime: now.subtract(const Duration(hours: 3)),
    startDatetime: now.subtract(const Duration(hours: 2)),
    endDatetime: now.subtract(const Duration(hours: 1)),
    startLat: 24.7136,
    startLng: 46.6753,
    endLat: 24.7140,
    endLng: 46.6760,
    startLocation: 'حي الملقا، الرياض',
    endLocation: 'حي الملقا، الرياض',
    submittedDate: now.subtract(const Duration(days: 2)),
    approvedDate: now.subtract(const Duration(days: 1)),
    approvedByName: _longEmployee,
    state: VisitState.done,
    isEscalated: true,
    escalationDate: now.subtract(const Duration(days: 1)),
    attachmentCount: 2,
    participants: const [
      VisitParticipant(id: 1, employeeName: _longEmployee),
      VisitParticipant(id: 2, employeeName: 'Sam Sales'),
    ],
  );
}

Customer _richCustomer() => Customer(
      id: 1,
      name: _longCustomer,
      latitude: 24.7136,
      longitude: 46.6753,
      address: 'طريق الملك عبد العزيز، حي الملقا، الرياض ١٢٤٧٣، السعودية',
      phone: '+966 55 123 4567',
      mobile: '+966 55 765 4321',
      email: 'procurement@gulf-contracting.com.sa',
      website: 'https://www.gulf-contracting.com.sa',
      vat: '300012345600003',
      isCompany: true,
      jobPosition: 'مدير المشتريات والعقود',
      parentCompanyName: 'مجموعة الخليج القابضة',
      categories: const ['عميل ذهبي', 'قطاع حكومي', 'أولوية عالية'],
      lastVisit: CustomerLastVisit(
        id: 7,
        employeeName: _longEmployee,
        checkInTime: DateTime.now().subtract(const Duration(hours: 5)),
        checkOutTime: DateTime.now().subtract(const Duration(hours: 4)),
      ),
    );

List<VisitActivity> _activities() {
  final now = DateTime.now();
  return [
    for (var i = 0; i < 8; i++)
      VisitActivity(
        id: i + 1,
        summary: 'مطلوب اعتماد الزيارة رقم ${i + 1} قبل نهاية يوم العمل',
        visitId: i + 1,
        visitRef: 'VIS/2026/${(i + 1).toString().padLeft(5, '0')}',
        deadline: now.add(Duration(days: i - 2)),
        urgency: switch (i % 3) {
          0 => ActivityUrgency.overdue,
          1 => ActivityUrgency.today,
          _ => ActivityUrgency.planned,
        },
      ),
  ];
}

// ─── Fakes ───────────────────────────────────────────────────────────────────
// `noSuchMethod` throws for anything not stubbed, so a screen that grows a new
// backend call fails loudly here instead of silently rendering an empty state
// and reporting "no overflow".

class _StubVisitsRepo implements VisitsRepository {
  @override
  Future<Visit?> readVisitFull(int visitId) async => _richVisit();

  @override
  Future<Visit?> getVisit(int visitId) async => _richVisit();

  @override
  Future<List<VisitAttachment>> readAttachments(int visitId) async => const [
        VisitAttachment(
          id: 1,
          name: 'محضر-الاجتماع-النهائي-مع-توقيعات-الأطراف.pdf',
          mimetype: 'application/pdf',
          fileSize: 482103,
        ),
        VisitAttachment(id: 2, name: 'site-photo.jpg', mimetype: 'image/jpeg', fileSize: 1843200),
      ];

  @override
  Future<bool> hasMockLocationFlag(int visitId) async => true;

  @override
  Future<List<VisitActivity>> myActivities() async => _activities();

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _StubCustomersRepo implements CustomersRepository {
  @override
  Future<Customer> getById(int id) async => _richCustomer();

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _FakeAuthRepo implements AuthRepository {
  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _StubAuthBloc extends AuthBloc {
  _StubAuthBloc(AuthUser? user) : super(repository: _FakeAuthRepo()) {
    if (user != null) emit(AuthState.authenticated(user));
  }

  /// The login screen fires `AuthLoginRequested` from its submit handler; the
  /// tests never tap it, but the guard keeps a stray event off the fake repo.
  @override
  void add(AuthEvent event) {}
}

class _StubListBloc extends VisitsListBloc {
  _StubListBloc() : super(repository: _StubVisitsRepo()) {
    emit(VisitsListState(status: VisitsListStatus.success));
  }

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

class _FakeApiClient implements ApiClient {
  @override
  void updateBaseUrl(String baseUrl) {}

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

// ─── Harness ─────────────────────────────────────────────────────────────────

typedef _Viewport = ({String name, Size size});

const _viewports = <_Viewport>[
  (name: 'small phone 320x640', size: Size(320, 640)),
  (name: 'landscape 720x360', size: Size(720, 360)),
  (name: 'tablet 800x1280', size: Size(800, 1280)),
];

/// Renders [page] and returns every layout error Flutter reported.
///
/// The handler is restored *before this returns*, not in a `tearDown`. That
/// ordering is load-bearing: the caller's `expect` runs immediately after, and
/// a failing `expect` throws a `TestFailure` — which, with our collector still
/// installed in place of the binding's, escapes into the zone as an uncaught
/// error. The binding then trips its own
/// `'_pendingExceptionDetails != null': A test overrode FlutterError.onError`
/// assertion and prints *that* instead of the overflow. In other words: with a
/// tearDown-based restore, a passing test passes and a failing one reports the
/// wrong reason — the exact case these tests exist to catch.
Future<List<FlutterErrorDetails>> _layoutErrors(
  WidgetTester tester,
  Widget page, {
  required Size size,
  required Locale locale,
  required double textScale,
  AuthUser? user = _manager,
}) async {
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
        BlocProvider<AuthBloc>(create: (_) => _StubAuthBloc(user)),
        BlocProvider<VisitsListBloc>(create: (_) => _StubListBloc()),
        BlocProvider<ServerConfigCubit>(
          create: (_) => ServerConfigCubit(
            repository: _FakeServerConfigRepo(),
            apiClient: _FakeApiClient(),
          ),
        ),
        // The auth chrome's language/theme chips read this during build, so
        // the login and server-setup screens will not render without it.
        BlocProvider<SettingsCubit>(
          create: (_) => SettingsCubit(repository: sl<SettingsRepository>()),
        ),
      ],
      child: MaterialApp(
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
        home: page,
      ),
    ),
  );
  // These screens load from a stubbed repository, so one microtask drain plus
  // the entry animations is enough. No pumpAndSettle: the visit map card hosts
  // an AmbientPulse, which by design never reports "no more frames".
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pump(const Duration(milliseconds: 900));

  FlutterError.onError = previous;

  // The map cards fetch OSM tiles, which the sandbox cannot reach; those
  // arrive through the same channel as a layout error and are an artefact of
  // the harness, not the app.
  return collected
      .where((e) => e.library != 'image resource service')
      .toList();
}

/// Fails with the overflow text *and the widget that caused it*.
///
/// `exceptionAsString()` alone yields "A RenderFlex overflowed by 25 pixels on
/// the right." — true, but it does not say which of a screen's several dozen
/// Rows did it, which is most of the work of fixing one. The library and the
/// error's `context` (Flutter fills this with "while laying out …") narrow it
/// to a single widget.
void _expectNoLayoutErrors(List<FlutterErrorDetails> errors) {
  expect(
    errors
        .map((e) => '${e.exceptionAsString()}  '
            '[library: ${e.library}, context: ${e.context}]')
        .toList(),
    isEmpty,
  );
}

void main() {
  setUpAll(() async {
    initializeDateFormatting();
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();

    // These screens resolve their collaborators from the locator during
    // `initState` / `BlocProvider.create`, so it has to be populated before the
    // first pump rather than injected per test.
    if (!sl.isRegistered<SettingsRepository>()) {
      sl.registerSingleton<SettingsRepository>(SettingsRepository(prefs: prefs));
    }
    if (!sl.isRegistered<VisitsRepository>()) {
      sl.registerSingleton<VisitsRepository>(_StubVisitsRepo());
    }
    if (!sl.isRegistered<CustomersRepository>()) {
      sl.registerSingleton<CustomersRepository>(_StubCustomersRepo());
    }

    PackageInfo.setMockInitialValues(
      appName: 'Visits',
      packageName: 'net.digitalharbor.visits',
      version: '1.0.0',
      buildNumber: '5',
      buildSignature: '',
    );
  });

  for (final vp in _viewports) {
    for (final locale in const [Locale('ar'), Locale('en')]) {
      for (final scale in const [1.0, 1.25]) {
        final tag = '${vp.name} · ${locale.languageCode} · ${scale}x';

        // The first screen every user meets, and the only one that must fit a
        // hero, a form, a checkbox row and a footer into a single viewport
        // *with the keyboard closed*.
        testWidgets('Login fits — $tag', (tester) async {
          _expectNoLayoutErrors(await _layoutErrors(
            tester,
            const LoginPage(),
            size: vp.size,
            locale: locale,
            textScale: scale,
            user: null,
          ));
        });

        // Shares the login chrome but adds two fields, a helper paragraph and
        // a detect-database action — the densest sheet in the app.
        testWidgets('Server setup fits — $tag', (tester) async {
          _expectNoLayoutErrors(await _layoutErrors(
            tester,
            const ServerSetupPage(),
            size: vp.size,
            locale: locale,
            textScale: scale,
            user: null,
          ));
        });

        // Every row packs a two-line Arabic summary, a visit reference and a
        // due date onto a ListTile that also carries a leading avatar and a
        // trailing chevron.
        testWidgets('Notifications fits — $tag', (tester) async {
          _expectNoLayoutErrors(await _layoutErrors(
            tester,
            const NotificationsPage(),
            size: vp.size,
            locale: locale,
            textScale: scale,
          ));
        });

        // The app's longest single column: hero, mock-GPS banner, map card and
        // six conditional sections, over a pinned action bar whose height the
        // list has to reserve.
        testWidgets('Visit detail fits — $tag', (tester) async {
          _expectNoLayoutErrors(await _layoutErrors(
            tester,
            const VisitDetailPage(visitId: 1),
            size: vp.size,
            locale: locale,
            textScale: scale,
          ));
        });

        // A collapsing SliverAppBar over a quick-action row that puts three
        // labelled buttons on one line — the row most likely to overflow on a
        // 320dp screen in Arabic.
        testWidgets('Customer detail fits — $tag', (tester) async {
          _expectNoLayoutErrors(await _layoutErrors(
            tester,
            CustomerDetailPage(customerId: 1, fallback: _richCustomer()),
            size: vp.size,
            locale: locale,
            textScale: scale,
          ));
        });

        // A form with a segmented button whose two Arabic labels plus icons
        // have to share the screen width.
        testWidgets('Create visit fits — $tag', (tester) async {
          _expectNoLayoutErrors(await _layoutErrors(
            tester,
            const CreateVisitPage(),
            size: vp.size,
            locale: locale,
            textScale: scale,
          ));
        });
      }
    }
  }
}
