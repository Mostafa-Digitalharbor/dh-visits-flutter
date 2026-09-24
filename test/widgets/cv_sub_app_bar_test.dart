import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/l10n/generated/app_localizations.dart';
import 'package:location_gps/shared/widgets/cv_sub_app_bar.dart';
import 'package:location_gps/shared/widgets/icon_action_chip.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'widget_harness.dart';

const _phoneArDark = Surface('phone · ar · dark',
    size: Size(390, 844), locale: arabic, brightness: Brightness.dark);

/// `context.r()`'s width factor for [s], written out so the expectation does
/// not just repeat the code under test.
double _widthScale(Surface s) => (s.size.width / 390).clamp(0.85, 1.2);

/// The bar the way the app mounts it: a Scaffold's app bar over a body.
Widget _screen(CvSubAppBar bar) =>
    Scaffold(appBar: bar, body: const SizedBox.expand());

Finder get _bar => find.byType(CvSubAppBar);
Finder get _chips =>
    find.descendant(of: _bar, matching: find.byType(IconActionChip));
Finder get _back => _chips.first;

/// A router-driven app with the harness's theme and localizations.
Future<void> _pumpRouter(WidgetTester tester, GoRouter router) async {
  tester.view.physicalSize = phoneEn.size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp.router(
    theme: AppTheme.light(),
    locale: english,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    routerConfig: router,
  ));
  await tester.pumpAndSettle();
}

Widget _page(String name) => Scaffold(
      appBar: CvSubAppBar(title: 'Title $name'),
      body: Text('body $name'),
    );

void main() {
  setUpAll(initHarness);

  group('CvSubAppBar layout', () {
    testOnEverySurface(
      'a long title, a long eyebrow and two actions fit one bar',
      (s) => _screen(CvSubAppBar(
        title: LongText.of(s),
        eyebrow: s.isArabic
            ? LongText.arabicPerson
            : LongText.english.toUpperCase(),
        actions: [
          IconActionChip(
            icon: Icons.search,
            tooltip: l10n(s.locale).commonSearch,
            onTap: () {},
          ),
          IconActionChip(
            icon: Icons.refresh,
            tooltip: l10n(s.locale).commonRetry,
            onTap: () {},
          ),
        ],
      )),
      verify: (tester, s) async {
        // The bar paints exactly the height it declares to the Scaffold.
        final bar = tester.widget<CvSubAppBar>(_bar);
        expect(tester.getSize(_bar).height, bar.preferredSize.height);
        expect(bar.preferredSize.height, CompSz.subAppBarHeight);

        // Both lines are single-line and ellipsize instead of wrapping.
        final texts = tester.widgetList<Text>(
            find.descendant(of: _bar, matching: find.byType(Text)));
        expect(texts, hasLength(2));
        for (final t in texts) {
          expect(t.maxLines, 1);
          expect(t.overflow, TextOverflow.ellipsis);
        }

        final barRect = tester.getRect(_bar);
        final titleRect = tester.getRect(find.text(LongText.of(s)));
        expect(_chips, findsNWidgets(3));
        final side = CompSz.chip * _widthScale(s);
        for (var i = 0; i < 3; i++) {
          final chip = _chips.at(i);
          final target = tester.getRect(chip);
          // A full touch target, inside the bar, clear of the title.
          expect(target.width, greaterThanOrEqualTo(IconSz.hit));
          expect(target.height, greaterThanOrEqualTo(IconSz.hit));
          expect(target.left, greaterThanOrEqualTo(barRect.left));
          expect(target.right, lessThanOrEqualTo(barRect.right));
          expect(target.top, greaterThanOrEqualTo(barRect.top));
          expect(target.bottom, lessThanOrEqualTo(barRect.bottom));
          expect(target.overlaps(titleRect), isFalse);
          // The panel keeps its scaled square shape; the bar used to squash
          // it to 39dp tall (48×39 on a tablet).
          final panel = tester.getSize(
              find.descendant(of: chip, matching: find.byType(Ink)));
          expect(panel.width, moreOrLessEquals(side));
          expect(panel.height, moreOrLessEquals(side));
        }
      },
    );

    testOnEverySurface(
      'a title alone sits centred beside the back chip',
      (s) => _screen(CvSubAppBar(title: l10n(s.locale).customersTitle)),
      verify: (tester, s) async {
        expect(_chips, findsOneWidget);
        expect(find.descendant(of: _bar, matching: find.byType(Text)),
            findsOneWidget);
        final title = tester.getRect(find.text(l10n(s.locale).customersTitle));
        expect(title.center.dy,
            moreOrLessEquals(tester.getCenter(_back).dy, epsilon: 1));
      },
    );

    testOnEverySurface(
      'a status-bar inset grows the bar by exactly that inset',
      (s) => _screen(CvSubAppBar(
        title: l10n(s.locale).customersTitle,
        eyebrow: l10n(s.locale).roleManager,
        topInset: 24,
      )),
      verify: (tester, s) async {
        final barRect = tester.getRect(_bar);
        expect(barRect.height, CompSz.subAppBarHeight + 24);
        expect(tester.widget<CvSubAppBar>(_bar).preferredSize.height,
            CompSz.subAppBarHeight + 24);
        // Nothing is drawn under the status bar.
        expect(tester.getRect(_back).top,
            greaterThanOrEqualTo(barRect.top + 24));
        expect(tester.getRect(find.text(l10n(s.locale).roleManager)).top,
            greaterThanOrEqualTo(barRect.top + 24));
      },
    );
  });

  group('CvSubAppBar direction', () {
    Widget bar(Surface s) => _screen(CvSubAppBar(
          title: l10n(s.locale).customersTitle,
          eyebrow: l10n(s.locale).roleManager,
          actions: [
            IconActionChip(icon: Icons.search, tooltip: 'a', onTap: () {}),
          ],
        ));

    testWidgets('English: back leads on the left and points left',
        (tester) async {
      await pumpSurface(tester, phoneEn, bar(phoneEn));
      final title = tester.getRect(find.text(l10n(english).customersTitle));
      expect(tester.getRect(_back).right, lessThanOrEqualTo(title.left));
      expect(tester.getRect(_chips.last).left,
          greaterThanOrEqualTo(title.right));
      expect(find.byIcon(Symbols.arrow_back_ios_new), findsOneWidget);
      expect(find.byIcon(Symbols.arrow_forward_ios), findsNothing);
      // The eyebrow sits above the title.
      expect(tester.getRect(find.text(l10n(english).roleManager)).bottom,
          lessThanOrEqualTo(title.top + 0.5));
      // Latin keeps the type scale's tracking.
      final style = tester
          .widget<Text>(find.text(l10n(english).customersTitle))
          .style!;
      expect(style.letterSpacing, AppType.appBarTitle.letterSpacing);
    });

    testWidgets('Arabic: back leads on the right and points right',
        (tester) async {
      await pumpSurface(tester, phoneAr, bar(phoneAr));
      final title = tester.getRect(find.text(l10n(arabic).customersTitle));
      expect(tester.getRect(_back).left, greaterThanOrEqualTo(title.right));
      expect(tester.getRect(_chips.last).right, lessThanOrEqualTo(title.left));
      expect(find.byIcon(Symbols.arrow_forward_ios), findsOneWidget);
      expect(find.byIcon(Symbols.arrow_back_ios_new), findsNothing);
      // Joined Arabic script must not be letter-spaced.
      for (final key in [
        l10n(arabic).customersTitle,
        l10n(arabic).roleManager,
      ]) {
        expect(tester.widget<Text>(find.text(key)).style!.letterSpacing, 0);
      }
    });
  });

  group('CvSubAppBar back', () {
    testWidgets('pops the go_router route it sits on', (tester) async {
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
        GoRoute(path: '/sub', builder: (_, _) => _page('sub')),
      ]);
      addTearDown(router.dispose);
      await _pumpRouter(tester, router);
      router.push('/sub');
      await tester.pumpAndSettle();
      expect(find.text('body sub'), findsOneWidget);

      await tester.tap(_back);
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(find.text('body sub'), findsNothing);
      expect(router.canPop(), isFalse);
    });

    testWidgets('one tap pops exactly one route', (tester) async {
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
        GoRoute(path: '/a', builder: (_, _) => _page('a')),
        GoRoute(path: '/b', builder: (_, _) => _page('b')),
      ]);
      addTearDown(router.dispose);
      await _pumpRouter(tester, router);
      router.push('/a');
      await tester.pumpAndSettle();
      router.push('/b');
      await tester.pumpAndSettle();

      await tester.tap(_back.hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('body a'), findsOneWidget);
      expect(find.text('body b'), findsNothing);
      expect(find.text('home'), findsNothing);
    });

    testWidgets('at the root of the router it does nothing and does not throw',
        (tester) async {
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, _) => _page('root')),
      ]);
      addTearDown(router.dispose);
      await _pumpRouter(tester, router);

      await tester.tap(_back);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('body root'), findsOneWidget);
    });

    testWidgets('falls back to the Navigator when there is no GoRouter',
        (tester) async {
      // Regression: `context.canPop()` asserted "No GoRouter found in context"
      // before the Navigator fallback could run.
      await pumpSurface(
        tester,
        phoneEn,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => _page('pushed')),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('body pushed'), findsOneWidget);

      await tester.tap(_back);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('body pushed'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });

  group('CvSubAppBar accessibility', () {
    for (final s in [phoneEn, phoneAr]) {
      testWidgets('back is a button labelled with the platform "Back" — $s',
          (tester) async {
        final handle = tester.ensureSemantics();
        await pumpSurface(tester, s, _screen(const CvSubAppBar(title: 'T')));
        final expected =
            MaterialLocalizations.of(tester.element(_bar)).backButtonTooltip;
        expect(tester.widget<Tooltip>(find.byType(Tooltip)).message, expected);
        // Looked up from inside the chip: getSemantics walks *up* to the
        // nearest node, and the chip's outermost render object is above it.
        expect(
          tester.getSemantics(
              find.descendant(of: _back, matching: find.byType(InkWell))),
          containsSemantics(
            tooltip: expected,
            isButton: true,
            hasTapAction: true,
          ),
        );
        handle.dispose();
      });
    }

    testWidgets('the Back tooltip follows the app language', (tester) async {
      await pumpSurface(tester, phoneEn, _screen(const CvSubAppBar(title: 'T')));
      final en = tester.widget<Tooltip>(find.byType(Tooltip)).message;
      await pumpSurface(tester, phoneAr, _screen(const CvSubAppBar(title: 'T')));
      final ar = tester.widget<Tooltip>(find.byType(Tooltip)).message;
      expect(en, 'Back');
      expect(ar, isNot(en));
      expect(ar, isNotEmpty);
    });

    for (final s in surfaces) {
      testWidgets('every chip meets the tap-target guidelines — $s',
          (tester) async {
        final handle = tester.ensureSemantics();
        await pumpSurface(
          tester,
          s,
          _screen(CvSubAppBar(
            title: LongText.of(s),
            eyebrow: l10n(s.locale).roleManager,
            actions: [
              IconActionChip(icon: Icons.search, tooltip: 'x', onTap: () {}),
            ],
          )),
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }

    testWidgets('the title block stops growing at 1.1× text scale',
        (tester) async {
      await pumpSurface(
        tester,
        surfaces.first, // 1.25×
        _screen(const CvSubAppBar(title: 'Title', eyebrow: 'Eyebrow')),
      );
      for (final text in ['Title', 'Eyebrow']) {
        final scaler = MediaQuery.textScalerOf(tester.element(find.text(text)));
        expect(scaler.scale(10), moreOrLessEquals(11));
      }
      // The back chip is chrome, not text: it is outside the clamp.
      expect(MediaQuery.textScalerOf(tester.element(_back)).scale(10),
          moreOrLessEquals(12.5));
    });
  });

  group('CvSubAppBar theming', () {
    for (final s in [phoneEn, _phoneArDark]) {
      testWidgets('colours come from the theme — $s', (tester) async {
        await pumpSurface(
          tester,
          s,
          _screen(const CvSubAppBar(title: 'Title', eyebrow: 'Eyebrow')),
        );
        final context = tester.element(_bar);
        final cs = Theme.of(context).colorScheme;
        expect(Theme.of(context).brightness, s.brightness);

        final material = tester.widget<Material>(
            find.descendant(of: _bar, matching: find.byType(Material)).first);
        expect(material.color, cs.surfaceContainerLowest);

        final container = tester.widget<Container>(
            find.descendant(of: _bar, matching: find.byType(Container)).first);
        final border = (container.decoration! as BoxDecoration).border!;
        expect((border as Border).bottom.color, context.x.outlineVariant);

        expect(tester.widget<Text>(find.text('Title')).style!.color,
            cs.onSurface);
        expect(tester.widget<Text>(find.text('Eyebrow')).style!.color,
            cs.onSurfaceVariant);
      });
    }
  });
}
