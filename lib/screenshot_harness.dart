// ─────────────────────────────────────────────────────────────────────────────
// Screenshot harness — NOT part of the shipped app.
//
// Renders each screen with mock data inside the real theme + localization, then
// captures a PNG into `store_assets/screenshots/`. Used to produce reference
// screenshots of the CURRENT UI (no backend / login needed) to hand to a
// designer.
//
// Run on Windows desktop (has filesystem + network for the Cairo web font):
//   flutter run -d windows -t lib/screenshot_harness.dart
//
// The app captures every screen, writes the PNGs, then exits by itself.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;

import 'app/theme.dart';
import 'core/settings/settings_cubit.dart';
import 'core/settings/settings_repository.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/models/user.dart';
import 'features/auth/view/login_page.dart';
import 'features/customers/bloc/customers_bloc.dart';
import 'features/customers/data/customers_repository.dart';
import 'features/customers/data/models/customer.dart';
import 'features/customers/view/customers_list_page.dart';
import 'features/dashboard/view/dashboard_page.dart';
import 'features/settings/view/settings_page.dart';
import 'features/visits/bloc/visits_list_bloc.dart';
import 'features/analytics/view/analytics_page.dart';
import 'features/review/view/review_page.dart';
import 'features/route/view/route_page.dart';
import 'features/visits/data/models/visit.dart';
import 'features/visits/data/visits_repository.dart';
import 'features/visits/view/report_sheet.dart';
import 'features/visits/view/visit_detail_page.dart';
import 'features/visits/view/visits_list_page.dart';
import 'l10n/generated/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();
  runApp(const _HarnessApp());
}

// ─── Mock data ───────────────────────────────────────────────────────────────

final DateTime _now = DateTime.now();
DateTime _ago(Duration d) => _now.toUtc().subtract(d);

const double _cairoLat = 30.0444;
const double _cairoLng = 31.2357;

final AuthUser _manager = const AuthUser(
  uid: 7,
  username: 'm.adel',
  employeeName: 'محمد عادل',
  employeeId: 3,
  isAdmin: true,
  isSystem: true,
  isManager: true,
  tz: 'Africa/Cairo',
);

final AuthUser _fieldUser = const AuthUser(
  uid: 12,
  username: 's.hassan',
  employeeName: 'سيد حسن',
  employeeId: 9,
  isManager: false,
  tz: 'Africa/Cairo',
);

final List<Visit> _visits = [
  Visit(
    id: 231,
    name: 'VIS/00231',
    customerId: 1,
    customerName: 'شركة النيل للتجارة',
    employeeId: 21,
    employeeName: 'أحمد محمود',
    checkInTime: _ago(const Duration(minutes: 45)),
    state: VisitStateType.checkedIn,
    lifecycleState: VisitLifecycleState.submit,
    checkInLat: _cairoLat + 0.004,
    checkInLng: _cairoLng + 0.003,
    customerLatitude: _cairoLat + 0.004,
    customerLongitude: _cairoLng + 0.003,
    customerAddress: 'برج النيل، كورنيش النيل، القاهرة',
    customerPhone: '+20 100 123 4567',
    visitTypeName: 'تحصيل',
    visitDate: _now,
    checkInState: VisitRangeState.inRange,
  ),
  Visit(
    id: 230,
    name: 'VIS/00230',
    customerId: 2,
    customerName: 'مجموعة الدلتا الصناعية',
    employeeId: 22,
    employeeName: 'خالد سمير',
    checkInTime: _ago(const Duration(minutes: 30)),
    state: VisitStateType.checkedIn,
    lifecycleState: VisitLifecycleState.submit,
    checkInLat: _cairoLat - 0.006,
    checkInLng: _cairoLng + 0.008,
    customerLatitude: _cairoLat - 0.006,
    customerLongitude: _cairoLng + 0.008,
    customerAddress: 'المنطقة الصناعية، مدينة نصر، القاهرة',
    customerPhone: '+20 122 765 4321',
    visitTypeName: 'ديمو',
    visitDate: _now,
    checkInState: VisitRangeState.inRange,
  ),
  Visit(
    id: 229,
    name: 'VIS/00229',
    customerId: 3,
    customerName: 'الشركة المصرية للأغذية',
    employeeId: 23,
    employeeName: 'منى فؤاد',
    checkInTime: _ago(const Duration(hours: 3)),
    checkOutTime: _ago(const Duration(hours: 2)),
    state: VisitStateType.checkedOut,
    lifecycleState: VisitLifecycleState.underReview,
    visitDuration: const Duration(hours: 1, minutes: 5),
    checkInLat: _cairoLat + 0.01,
    checkInLng: _cairoLng - 0.01,
    checkOutLat: _cairoLat + 0.0102,
    checkOutLng: _cairoLng - 0.0099,
    customerLatitude: _cairoLat + 0.01,
    customerLongitude: _cairoLng - 0.01,
    customerAddress: 'شارع الهرم، الجيزة',
    customerPhone: '+20 109 999 8888',
    visitTypeName: 'متابعة',
    visitDate: _now,
    checkInState: VisitRangeState.inRange,
    checkOutState: VisitRangeState.inRange,
  ),
  Visit(
    id: 228,
    name: 'VIS/00228',
    customerId: 4,
    customerName: 'أسواق المستقبل',
    employeeId: 24,
    employeeName: 'ياسر عبد الله',
    state: VisitStateType.unknown,
    lifecycleState: VisitLifecycleState.submit,
    customerLatitude: _cairoLat + 0.02,
    customerLongitude: _cairoLng + 0.015,
    customerAddress: 'التجمع الخامس، القاهرة الجديدة',
    customerPhone: '+20 111 222 3344',
    visitTypeName: 'تحصيل',
    visitDate: _now.subtract(const Duration(days: 2)),
  ),
  Visit(
    id: 232,
    name: 'VIS/00232',
    customerId: 5,
    customerName: 'بنك القاهرة - فرع المعادي',
    employeeId: 25,
    employeeName: 'هدى علي',
    state: VisitStateType.unknown,
    lifecycleState: VisitLifecycleState.submit,
    customerLatitude: _cairoLat - 0.03,
    customerLongitude: _cairoLng - 0.005,
    customerAddress: 'شارع 9، المعادي، القاهرة',
    customerPhone: '+20 128 555 6677',
    visitTypeName: 'ديمو',
    visitDate: _now.add(const Duration(days: 1)),
  ),
  Visit(
    id: 220,
    name: 'VIS/00220',
    customerId: 6,
    customerName: 'صيدليات الشفاء',
    employeeId: 21,
    employeeName: 'أحمد محمود',
    checkInTime: _ago(const Duration(hours: 30)),
    checkOutTime: _ago(const Duration(hours: 29)),
    state: VisitStateType.checkedOut,
    lifecycleState: VisitLifecycleState.done,
    visitDuration: const Duration(minutes: 52),
    checkInLat: _cairoLat,
    checkInLng: _cairoLng,
    checkOutLat: _cairoLat,
    checkOutLng: _cairoLng,
    customerLatitude: _cairoLat,
    customerLongitude: _cairoLng,
    customerAddress: 'وسط البلد، القاهرة',
    customerPhone: '+20 100 000 1111',
    visitTypeName: 'تدريب',
    visitDate: _now.subtract(const Duration(days: 1)),
    checkInState: VisitRangeState.inRange,
    checkOutState: VisitRangeState.notInRange,
  ),
];

// Three visits in `under_review` for the review-queue screenshot (one flagged
// out-of-range), matching the design's screen 09.
final List<Visit> _reviewVisits = [
  Visit(
    id: 231,
    name: 'VIS/00231',
    customerName: 'بنك القاهرة - فرع المعادي',
    employeeName: 'منى فؤاد',
    checkInTime: _ago(const Duration(hours: 3)),
    checkOutTime: _ago(const Duration(hours: 2)),
    state: VisitStateType.checkedOut,
    lifecycleState: VisitLifecycleState.underReview,
    visitDuration: const Duration(minutes: 55),
    visitTypeName: 'متابعة',
    visitDate: _now,
    checkInState: VisitRangeState.inRange,
    checkOutState: VisitRangeState.inRange,
  ),
  Visit(
    id: 229,
    name: 'VIS/00229',
    customerName: 'شركة النيل للتجارة',
    employeeName: 'أحمد محمود',
    checkInTime: _ago(const Duration(hours: 5)),
    checkOutTime: _ago(const Duration(hours: 4)),
    state: VisitStateType.checkedOut,
    lifecycleState: VisitLifecycleState.underReview,
    visitDuration: const Duration(hours: 1, minutes: 5),
    visitTypeName: 'تحصيل',
    visitDate: _now,
    checkInState: VisitRangeState.inRange,
    checkOutState: VisitRangeState.inRange,
  ),
  Visit(
    id: 228,
    name: 'VIS/00228',
    customerName: 'أسواق المستقبل',
    employeeName: 'خالد سمير',
    checkInTime: _ago(const Duration(hours: 7)),
    checkOutTime: _ago(const Duration(hours: 6, minutes: 35)),
    state: VisitStateType.checkedOut,
    lifecycleState: VisitLifecycleState.underReview,
    visitDuration: const Duration(minutes: 25),
    visitTypeName: 'صيانة',
    visitDate: _now,
    checkInState: VisitRangeState.notInRange,
    checkOutState: VisitRangeState.notInRange,
  ),
];

final List<Customer> _customers = [
  Customer(
    id: 1,
    name: 'شركة النيل للتجارة',
    latitude: _cairoLat + 0.004,
    longitude: _cairoLng + 0.003,
    address: 'برج النيل، كورنيش النيل، القاهرة',
    phone: '+20 100 123 4567',
    lastVisit: CustomerLastVisit(
      id: 231,
      employeeName: 'أحمد محمود',
      checkInTime: _now.subtract(const Duration(minutes: 45)),
    ),
  ),
  Customer(
    id: 2,
    name: 'مجموعة الدلتا الصناعية',
    latitude: _cairoLat - 0.006,
    longitude: _cairoLng + 0.008,
    address: 'المنطقة الصناعية، مدينة نصر، القاهرة',
    phone: '+20 122 765 4321',
    lastVisit: CustomerLastVisit(
      id: 230,
      employeeName: 'خالد سمير',
      checkInTime: _now.subtract(const Duration(hours: 2)),
      checkOutTime: _now.subtract(const Duration(hours: 1)),
    ),
  ),
  Customer(
    id: 3,
    name: 'الشركة المصرية للأغذية',
    latitude: _cairoLat + 0.01,
    longitude: _cairoLng - 0.01,
    address: 'شارع الهرم، الجيزة',
    phone: '+20 109 999 8888',
  ),
  Customer(
    id: 4,
    name: 'أسواق المستقبل',
    latitude: _cairoLat + 0.02,
    longitude: _cairoLng + 0.015,
    address: 'التجمع الخامس، القاهرة الجديدة',
    phone: '+20 111 222 3344',
  ),
  Customer(
    id: 5,
    name: 'بنك القاهرة - فرع المعادي',
    latitude: _cairoLat - 0.03,
    longitude: _cairoLng - 0.005,
    address: 'شارع 9، المعادي، القاهرة',
    phone: '+20 128 555 6677',
  ),
  Customer(
    id: 6,
    name: 'صيدليات الشفاء',
    latitude: _cairoLat,
    longitude: _cairoLng,
    address: 'وسط البلد، القاهرة',
    phone: '+20 100 000 1111',
    lastVisit: CustomerLastVisit(
      id: 220,
      employeeName: 'أحمد محمود',
      checkInTime: _now.subtract(const Duration(hours: 30)),
      checkOutTime: _now.subtract(const Duration(hours: 29)),
    ),
  ),
];

// ─── Fake repositories (only the read paths the screens hit) ─────────────────

class _FakeVisitsRepo implements VisitsRepository {
  final List<Visit> data;
  _FakeVisitsRepo(this.data);
  @override
  Future<List<Visit>> list({
    int? customerId,
    int? employeeId,
    DateTime? from,
    DateTime? to,
    String state = 'all',
    bool includeDrafts = false,
  }) async =>
      data;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeCustomersRepo implements CustomersRepository {
  final List<Customer> data;
  _FakeCustomersRepo(this.data);
  @override
  Future<List<Customer>> list({String? search, int limit = 50, int offset = 0}) async => data;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeAuthRepo implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeSettingsRepo implements SettingsRepository {
  @override
  String? readThemeMode() => null;
  @override
  Future<void> writeThemeMode(String value) async {}
  @override
  String? readLocale() => null;
  @override
  Future<void> writeLocale(String value) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ─── Fake blocs (seeded with the mock data) ──────────────────────────────────

class _FakeAuthBloc extends AuthBloc {
  _FakeAuthBloc(AuthState seed) : super(repository: _FakeAuthRepo()) {
    emit(seed);
  }
}

class _FakeVisitsListBloc extends VisitsListBloc {
  _FakeVisitsListBloc(List<Visit> items) : super(repository: _FakeVisitsRepo(items)) {
    emit(VisitsListState(status: VisitsListStatus.success, items: items));
  }
}

class _FakeCustomersBloc extends CustomersBloc {
  _FakeCustomersBloc(List<Customer> items) : super(repository: _FakeCustomersRepo(items)) {
    emit(CustomersState(status: CustomersStatus.success, items: items));
  }
}

class _FakeSettingsCubit extends SettingsCubit {
  _FakeSettingsCubit() : super(repository: _FakeSettingsRepo());
}

// ─── Screen builders ─────────────────────────────────────────────────────────

Widget _wrapScaffold(String title, Widget body) => Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: true),
      body: body,
    );

Widget _loginScreen() => MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: _FakeAuthBloc(const AuthState.unauthenticated())),
        BlocProvider<SettingsCubit>.value(value: _FakeSettingsCubit()),
      ],
      child: const LoginPage(),
    );

Widget _visitsScreen({required bool manager, required String title}) => MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(
          value: _FakeAuthBloc(AuthState.authenticated(manager ? _manager : _fieldUser)),
        ),
        BlocProvider<VisitsListBloc>.value(value: _FakeVisitsListBloc(_visits)),
      ],
      child: _wrapScaffold(title, const VisitsListPage()),
    );

Widget _detailScreen(Visit visit) => MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: _FakeAuthBloc(AuthState.authenticated(_manager))),
        BlocProvider<VisitsListBloc>.value(value: _FakeVisitsListBloc(_visits)),
      ],
      child: VisitDetailPage(visitId: visit.id, initial: visit),
    );

Widget _dashboardScreen() => MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: _FakeAuthBloc(AuthState.authenticated(_manager))),
        BlocProvider<VisitsListBloc>.value(value: _FakeVisitsListBloc(_visits)),
      ],
      child: _wrapScaffold('لوحة التحكم', const DashboardPage()),
    );

Widget _customersScreen() => MultiBlocProvider(
      providers: [
        BlocProvider<CustomersBloc>.value(value: _FakeCustomersBloc(_customers)),
      ],
      child: _wrapScaffold('العملاء', const CustomersListPage()),
    );

Widget _settingsScreen() => MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: _FakeAuthBloc(AuthState.authenticated(_manager))),
        BlocProvider<SettingsCubit>.value(value: _FakeSettingsCubit()),
      ],
      child: const SettingsPage(),
    );

Widget _analyticsScreen() => MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: _FakeAuthBloc(AuthState.authenticated(_manager))),
        BlocProvider<VisitsListBloc>.value(value: _FakeVisitsListBloc(_visits)),
      ],
      child: _wrapScaffold('التحليلات', const AnalyticsPage()),
    );

Widget _reviewScreen() => MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: _FakeAuthBloc(AuthState.authenticated(_manager))),
        BlocProvider<VisitsListBloc>.value(value: _FakeVisitsListBloc(_reviewVisits)),
      ],
      child: const ReviewPage(),
    );

Widget _routeScreen() => MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: _FakeAuthBloc(AuthState.authenticated(_fieldUser))),
        BlocProvider<VisitsListBloc>.value(value: _FakeVisitsListBloc(_visits)),
      ],
      child: _wrapScaffold('مسار اليوم', const RoutePage()),
    );

Widget _reportScreen() => Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.40),
      body: const ReportSheet(),
    );

class _Shot {
  final String name;
  final Locale locale;
  final ThemeMode themeMode;
  final Widget child;
  _Shot(this.name, this.locale, this.themeMode, this.child);
}

const _ar = Locale('ar');
const _en = Locale('en');

List<_Shot> _buildShots() => [
      _Shot('01_login_ar_light', _ar, ThemeMode.light, _loginScreen()),
      _Shot('02_login_ar_dark', _ar, ThemeMode.dark, _loginScreen()),
      _Shot('03_login_en_light', _en, ThemeMode.light, _loginScreen()),
      _Shot('04_visits_admin_ar_light', _ar, ThemeMode.light,
          _visitsScreen(manager: true, title: 'الزيارات')),
      _Shot('05_visits_admin_ar_dark', _ar, ThemeMode.dark,
          _visitsScreen(manager: true, title: 'الزيارات')),
      _Shot('06_visits_user_ar_light', _ar, ThemeMode.light,
          _visitsScreen(manager: false, title: 'زياراتي')),
      _Shot('07_visit_detail_admin_ar_light', _ar, ThemeMode.light, _detailScreen(_visits[2])),
      _Shot('08_visit_detail_admin_ar_dark', _ar, ThemeMode.dark, _detailScreen(_visits[2])),
      _Shot('09_visit_detail_active_ar_light', _ar, ThemeMode.light, _detailScreen(_visits[0])),
      _Shot('10_dashboard_ar_light', _ar, ThemeMode.light, _dashboardScreen()),
      _Shot('11_dashboard_ar_dark', _ar, ThemeMode.dark, _dashboardScreen()),
      _Shot('12_customers_ar_light', _ar, ThemeMode.light, _customersScreen()),
      _Shot('13_settings_ar_light', _ar, ThemeMode.light, _settingsScreen()),
      _Shot('14_analytics_ar_light', _ar, ThemeMode.light, _analyticsScreen()),
      _Shot('15_review_ar_light', _ar, ThemeMode.light, _reviewScreen()),
      _Shot('16_route_ar_light', _ar, ThemeMode.light, _routeScreen()),
      _Shot('17_report_ar_light', _ar, ThemeMode.light, _reportScreen()),
      _Shot('18_analytics_ar_dark', _ar, ThemeMode.dark, _analyticsScreen()),
    ];

// ─── Capture driver ──────────────────────────────────────────────────────────

class _HarnessApp extends StatefulWidget {
  const _HarnessApp();
  @override
  State<_HarnessApp> createState() => _HarnessAppState();
}

class _HarnessAppState extends State<_HarnessApp> {
  late final List<_Shot> _shots = _buildShots();
  // A dedicated boundary key per shot so each capture targets a fresh render
  // object (reusing one key let an occasional stale frame repeat across shots).
  late final List<GlobalKey> _keys = List.generate(_shots.length, (_) => GlobalKey());
  int _index = 0;
  bool _done = false;

  static const double _w = 390;
  static const double _h = 844;
  static const double _pixelRatio = 3.0;
  static const String _outDir =
      r'E:\mostafa\Companies\Digital_Harbor\Visits\location_gps\store_assets\screenshots';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    // Give the Cairo web font time to download + cache on the first frame so
    // it doesn't fall back to Roboto on the earliest screenshots.
    await Future.delayed(const Duration(seconds: 4));
    for (var i = 0; i < _shots.length; i++) {
      setState(() => _index = i);
      // Pump real frames (not just wall-clock) so the new subtree actually
      // builds, dispatches its mock load, loads map tiles, and settles
      // animations before we rasterise the boundary.
      for (var f = 0; f < 9; f++) {
        await WidgetsBinding.instance.endOfFrame;
        await Future.delayed(const Duration(milliseconds: 180));
      }
      await _capture(i, _shots[i].name);
    }
    setState(() => _done = true);
    await Future.delayed(const Duration(milliseconds: 400));
    exit(0);
  }

  Future<void> _capture(int index, String name) async {
    try {
      final ctx = _keys[index].currentContext;
      if (ctx == null) {
        stdout.writeln('[harness] SKIP $name: boundary not mounted');
        return;
      }
      final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: _pixelRatio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) return;
      final file = File('$_outDir/$name.png');
      await file.create(recursive: true);
      await file.writeAsBytes(bytes.buffer.asUint8List());
      stdout.writeln('[harness] wrote ${file.path}');
    } catch (e) {
      stdout.writeln('[harness] FAILED $name: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ColoredBox(color: Colors.black),
      );
    }
    final shot = _shots[_index];
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: shot.themeMode,
      locale: shot.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // FittedBox scales the fixed 390×844 phone frame to fit whatever the
      // desktop window size is (no overflow), while the RepaintBoundary still
      // rasterises at the native 390×844 × pixelRatio — so window size never
      // affects the output resolution.
      home: ColoredBox(
        color: const Color(0xFF555555),
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: RepaintBoundary(
              key: _keys[_index],
              child: SizedBox(
                width: _w,
                height: _h,
                child: MediaQuery(
                  data: const MediaQueryData(
                    size: Size(_w, _h),
                    devicePixelRatio: _pixelRatio,
                    padding: EdgeInsets.only(top: 44, bottom: 24),
                  ),
                  child: shot.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
