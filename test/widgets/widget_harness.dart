// Shared harness for the shared-widget suites under test/widgets/.
//
// Every widget is pumped across the surfaces the app really ships into, and a
// layout error fails the test. A `RenderFlex overflow` is a debug-only
// assertion — release builds clip silently — so these suites are the only
// place such a regression is caught.
//
//   * 320×568 — the smallest phone still in use.
//   * 720×360 — a phone on its side, where height is scarce.
//   * 800×1280 — a tablet.
//   * ar + en — Arabic runs longer and mirrors the layout.
//   * 1.25× — the app's own text-scale ceiling (see `App`).
//   * light + dark — every token has a dark counterpart that must resolve.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/l10n/generated/app_localizations.dart';

/// One device configuration a widget has to render on.
class Surface {
  final String name;
  final Size size;
  final Locale locale;
  final double textScale;
  final Brightness brightness;

  const Surface(
    this.name, {
    required this.size,
    required this.locale,
    this.textScale = 1.0,
    this.brightness = Brightness.light,
  });

  bool get isArabic => locale.languageCode == 'ar';

  @override
  String toString() => name;
}

const arabic = Locale('ar');
const english = Locale('en');

/// The matrix every shared widget is rendered on.
const surfaces = <Surface>[
  Surface('small phone · ar · 1.25x',
      size: Size(320, 568), locale: arabic, textScale: Responsive.maxTextScale),
  Surface('small phone · en · 1.25x',
      size: Size(320, 568), locale: english, textScale: Responsive.maxTextScale),
  Surface('landscape · ar · dark',
      size: Size(720, 360), locale: arabic, brightness: Brightness.dark),
  Surface('tablet · en · dark · 1.25x',
      size: Size(800, 1280),
      locale: english,
      textScale: Responsive.maxTextScale,
      brightness: Brightness.dark),
];

/// A default surface for behaviour tests that don't care about layout.
const phoneEn = Surface('phone · en', size: Size(390, 844), locale: english);
const phoneAr = Surface('phone · ar', size: Size(390, 844), locale: arabic);

/// Loads the date symbols the app loads at start-up (see `main.dart`).
Future<void> initHarness() async {
  await initializeDateFormatting('en');
  await initializeDateFormatting('ar');
}

/// The app's localizations for [locale], without a widget tree.
AppLocalizations l10n(Locale locale) => lookupAppLocalizations(locale);

/// Pumps [child] inside the app's theme, localizations and text-scale clamp,
/// sized to [surface]. [scrollable] wraps the child in a scroll view for
/// widgets that are meant to live in one (lists, long cards).
Future<void> pumpSurface(
  WidgetTester tester,
  Surface surface,
  Widget child, {
  bool scrollable = false,
  bool wrapInScaffold = true,
  Duration settle = const Duration(milliseconds: 600),
}) async {
  tester.view.physicalSize = surface.size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  Widget body = child;
  if (scrollable) body = SingleChildScrollView(child: body);
  if (wrapInScaffold) body = Scaffold(body: SafeArea(child: body));

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: surface.brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      locale: surface.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(surface.textScale),
        ),
        child: app!,
      ),
      home: body,
    ),
  );
  await tester.pump(settle);
}

/// Fails the test on any layout error Flutter reported, ignoring map-tile
/// downloads (the test sandbox has no network).
void expectCleanLayout(WidgetTester tester) {
  final error = tester.takeException();
  if (error == null) return;
  if ('$error'.contains('tile.openstreetmap.org')) return;
  fail('layout error: $error');
}

/// Registers one test per [surfaces] entry that pumps [build] and asserts a
/// clean layout, then runs [verify] for extra checks on that surface.
void testOnEverySurface(
  String description,
  Widget Function(Surface surface) build, {
  bool scrollable = false,
  Future<void> Function(WidgetTester tester, Surface surface)? verify,
}) {
  for (final surface in surfaces) {
    testWidgets('$description — $surface', (tester) async {
      await pumpSurface(tester, surface, build(surface), scrollable: scrollable);
      expectCleanLayout(tester);
      if (verify != null) await verify(tester, surface);
      expectCleanLayout(tester);
    });
  }
}

/// Long, realistic values: the ones that actually break layouts.
abstract final class LongText {
  static const arabicCompany =
      'شركة الخليج للمقاولات والاستثمار العقاري المحدودة — فرع الرياض الرئيسي';
  static const arabicPerson = 'عبد الرحمن بن محمد بن عبد الله السبيعي';
  static const english =
      'Gulf Contracting and Real Estate Investment Company Limited — Riyadh HQ';

  static String of(Surface s) => s.isArabic ? arabicCompany : english;
}
