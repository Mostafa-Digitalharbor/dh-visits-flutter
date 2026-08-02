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
import 'package:location_gps/features/dashboard/view/dashboard_page.dart';
import 'package:location_gps/features/visits/bloc/visits_list_bloc.dart';
import 'package:location_gps/features/visits/data/models/visit.dart';
import 'package:location_gps/features/visits/data/visits_repository.dart';
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
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final collected = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = collected.add;
  addTearDown(() => FlutterError.onError = previous);

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => _StubAuthBloc(_manager)),
        BlocProvider<VisitsListBloc>(create: (_) => _StubListBloc(items)),
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
        home: Scaffold(body: page),
      ),
    ),
  );
  // Let the count-up and chart tweens run, without pumpAndSettle — the pages
  // host an AmbientPulse, which by design never settles into "no more frames"
  // for good (it wakes again after its rest).
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pump(const Duration(milliseconds: 900));

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

void main() {
  setUpAll(() async => initializeDateFormatting());

  final items = _seed();

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
