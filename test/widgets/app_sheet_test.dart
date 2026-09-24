import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/shared/widgets/app_sheet.dart';

import 'widget_harness.dart';

const _submit = Key('sheet-submit');
const _field = Key('sheet-field');
const _open = 'open';

/// A realistic form body: a multiline note, an optional second field, and a
/// submit button that pops [result].
Widget _form(Surface s, {bool tall = false, Object result = 'submitted'}) {
  final t = l10n(s.locale);
  return Builder(
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: _field,
          minLines: 4,
          maxLines: 6,
          decoration: InputDecoration(
            labelText: t.wfFieldPurpose,
            helperText: LongText.of(s),
            helperMaxLines: 3,
          ),
        ),
        if (tall) ...[
          const SizedBox(height: 16),
          TextField(
            minLines: 4,
            maxLines: 4,
            decoration: InputDecoration(labelText: t.wfRescheduleTitle),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          key: _submit,
          onPressed: () => Navigator.of(context).pop(result),
          child: Text(t.wfActionSubmit),
        ),
      ],
    ),
  );
}

/// A page with a button that opens [sheet] through [showAppSheet].
Widget _launcher(
  WidgetBuilder sheet, {
  void Function(Object? result)? onResult,
}) => Builder(
  builder: (context) => Center(
    child: TextButton(
      onPressed: () async {
        final result = await showAppSheet<Object>(
          context: context,
          builder: sheet,
        );
        onResult?.call(result);
      },
      child: const Text(_open),
    ),
  ),
);

Widget _formSheet(Surface s, {String? title, bool tall = false}) => _launcher(
  (_) => AppFormSheet(
    title: title ?? l10n(s.locale).wfRejectReason,
    child: _form(s, tall: tall),
  ),
);

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text(_open));
  await tester.pumpAndSettle();
}

Finder get _sheet => find.byType(BottomSheet);

/// The visible sheet: `BottomSheet` spans the route and bounds the Material
/// inside it, so the Material is what has the sheet's real size.
Finder get _panel =>
    find.descendant(of: _sheet, matching: find.byType(Material)).first;

/// The form's own scroll view — the outermost Scrollable (text fields carry
/// their own inside it).
Finder get _sheetScrollable => find
    .descendant(
      of: find.byType(AppFormSheet),
      matching: find.byType(Scrollable),
    )
    .first;

Finder get _close => find.descendant(
  of: find.byType(AppSheetHeader),
  matching: find.byType(IconButton),
);

void main() {
  setUpAll(initHarness);

  group('AppFormSheet layout', () {
    testOnEverySurface(
      'a form sheet with a long title opens and every part is reachable',
      (s) => _formSheet(s, title: '${LongText.of(s)} ${LongText.of(s)}'),
      verify: (tester, s) async {
        await _openSheet(tester);
        expect(find.byType(AppFormSheet), findsOneWidget);
        expect(_close, findsOneWidget);
        final sheet = tester.getRect(_panel);
        expect(sheet.width, lessThanOrEqualTo(CompSz.dialogMaxWidth));
        // The close button is never pushed out by the title.
        final close = tester.getRect(_close);
        expect(sheet.left <= close.left && close.right <= sheet.right, isTrue);
        await tester.scrollUntilVisible(
          find.byKey(_submit),
          60,
          scrollable: _sheetScrollable,
        );
        expect(
          tester.getRect(find.byKey(_submit)).bottom,
          lessThanOrEqualTo(s.size.height),
        );
      },
    );

    testOnEverySurface(
      'with the keyboard up the form stays above it and scrolls',
      (s) => _formSheet(s, tall: true),
      verify: (tester, s) async {
        await _openSheet(tester);
        final inset = s.size.height * 0.45;
        tester.view.viewInsets = FakeViewPadding(bottom: inset);
        await tester.pumpAndSettle();
        expectCleanLayout(tester);

        final visibleBottom = s.size.height - inset;
        expect(
          tester.getRect(_sheetScrollable).bottom,
          lessThanOrEqualTo(visibleBottom + 0.01),
        );
        await tester.scrollUntilVisible(
          find.byKey(_submit),
          60,
          scrollable: _sheetScrollable,
        );
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.byKey(_submit)).bottom,
          lessThanOrEqualTo(visibleBottom + 0.01),
        );
      },
    );
  });

  group('showAppSheet behaviour', () {
    testWidgets('returns the value the sheet pops', (tester) async {
      final results = <Object?>[];
      await pumpSurface(
        tester,
        phoneEn,
        _launcher(
          (_) => AppFormSheet(title: 'T', child: _form(phoneEn, result: 42)),
          onResult: results.add,
        ),
      );
      await _openSheet(tester);
      await tester.tap(find.byKey(_submit));
      await tester.pumpAndSettle();
      expect(results, [42]);
      expect(_sheet, findsNothing);
    });

    testWidgets('the close button dismisses it with null', (tester) async {
      final results = <Object?>[];
      await pumpSurface(
        tester,
        phoneEn,
        _launcher(
          (_) => AppFormSheet(title: 'T', child: _form(phoneEn)),
          onResult: results.add,
        ),
      );
      await _openSheet(tester);
      await tester.tap(_close);
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);
      expect(results, [null]);
      // Only the sheet was popped — the page that opened it is still there.
      expect(find.text(_open), findsOneWidget);
    });

    testWidgets('tapping the scrim dismisses it with null', (tester) async {
      final results = <Object?>[];
      await pumpSurface(
        tester,
        phoneEn,
        _launcher(
          (_) => AppFormSheet(title: 'T', child: _form(phoneEn)),
          onResult: results.add,
        ),
      );
      await _openSheet(tester);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);
      expect(results, [null]);
    });

    testWidgets('close respects a PopScope that refuses to pop', (
      tester,
    ) async {
      // `maybePop` lets a form with unsaved changes intercept the close.
      final attempts = <bool>[];
      await pumpSurface(
        tester,
        phoneEn,
        _launcher(
          (_) => PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) => attempts.add(didPop),
            child: AppFormSheet(title: 'T', child: _form(phoneEn)),
          ),
        ),
      );
      await _openSheet(tester);
      await tester.tap(_close);
      await tester.pumpAndSettle();
      expect(attempts, [false]);
      expect(_sheet, findsOneWidget);
    });

    testWidgets('a phone-width sheet spans the screen', (tester) async {
      await pumpSurface(tester, phoneEn, _formSheet(phoneEn));
      await _openSheet(tester);
      final sheet = tester.getRect(_panel);
      expect(sheet.width, phoneEn.size.width);
      expect(sheet.bottom, phoneEn.size.height);
    });

    testWidgets('a tablet sheet is bound to the dialog width and centred', (
      tester,
    ) async {
      const tablet = Surface('tablet', size: Size(800, 1280), locale: english);
      await pumpSurface(tester, tablet, _formSheet(tablet));
      await _openSheet(tester);
      final sheet = tester.getRect(_panel);
      expect(sheet.width, CompSz.dialogMaxWidth);
      expect(sheet.center.dx, tablet.size.width / 2);
      expect(sheet.bottom, tablet.size.height);
    });

    testWidgets('never slides under the status bar', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        _launcher(
          (_) => AppFormSheet(
            title: 'T',
            child: Column(
              children: [
                for (var i = 0; i < 20; i++) const SizedBox(height: 80),
                _form(phoneEn),
              ],
            ),
          ),
        ),
      );
      tester.view.padding = const FakeViewPadding(top: 48);
      await tester.pump();
      await _openSheet(tester);
      expect(tester.getRect(_panel).top, greaterThanOrEqualTo(48));
      expectCleanLayout(tester);
    });

    testWidgets('surface background and rounded top corners', (tester) async {
      for (final s in [phoneEn, surfaces[2]]) {
        await pumpSurface(tester, s, _formSheet(s));
        await _openSheet(tester);
        final sheet = tester.widget<BottomSheet>(_sheet);
        final scheme = Theme.of(tester.element(_sheet)).colorScheme;
        expect(scheme.brightness, s.brightness);
        expect(sheet.backgroundColor, scheme.surface, reason: '$s');
        expect(
          sheet.shape,
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
          ),
        );
        await tester.tap(_close);
        await tester.pumpAndSettle();
      }
    });
  });

  group('AppFormSheet behaviour', () {
    testWidgets('the keyboard inset lifts the content by exactly the inset', (
      tester,
    ) async {
      await pumpSurface(tester, phoneEn, _formSheet(phoneEn));
      await _openSheet(tester);
      final before = tester.getRect(find.byKey(_submit)).bottom;
      final sheetBefore = tester.getRect(_panel);

      const inset = 300.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: inset);
      await tester.pumpAndSettle();
      final after = tester.getRect(find.byKey(_submit)).bottom;
      expect(before - after, moreOrLessEquals(inset));
      // The sheet grows by the inset rather than covering its own content.
      expect(
        tester.getRect(_panel).height - sheetBefore.height,
        moreOrLessEquals(inset),
      );

      // And settles back when the keyboard closes.
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(_submit)).bottom,
        moreOrLessEquals(before),
      );
    });

    testWidgets('on a short screen with the keyboard up, submit still works', (
      tester,
    ) async {
      const small = Surface(
        'small',
        size: Size(320, 568),
        locale: arabic,
        textScale: Responsive.maxTextScale,
      );
      final results = <Object?>[];
      await pumpSurface(
        tester,
        small,
        _launcher(
          (_) => AppFormSheet(
            title: LongText.arabicCompany,
            child: _form(small, tall: true, result: 'ok'),
          ),
          onResult: results.add,
        ),
      );
      await _openSheet(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      expectCleanLayout(tester);

      expect(_sheetScrollable, findsOneWidget);
      final position = tester.state<ScrollableState>(_sheetScrollable).position;
      expect(
        position.maxScrollExtent,
        greaterThan(0),
        reason: 'the form should need to scroll here',
      );
      await tester.scrollUntilVisible(
        find.byKey(_submit),
        60,
        scrollable: _sheetScrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_submit));
      await tester.pumpAndSettle();
      expect(results, ['ok']);
    });

    testWidgets('header, gap, then the body, inside responsive padding', (
      tester,
    ) async {
      await pumpSurface(tester, phoneEn, _formSheet(phoneEn));
      await _openSheet(tester);
      final sheet = tester.getRect(_panel);
      final header = tester.getRect(find.byType(AppSheetHeader));
      final field = tester.getRect(find.byKey(_field));
      // 390dp is the design width, so r(16) == 16 here.
      expect(header.left - sheet.left, Insets.x4);
      expect(sheet.right - header.right, Insets.x4);
      expect(header.top - sheet.top, Insets.x4);
      expect(field.left, header.left);
      expect(field.top, greaterThan(header.bottom));
    });

    testWidgets('padding shrinks with a narrow screen', (tester) async {
      const narrow = Surface('narrow', size: Size(320, 640), locale: english);
      await pumpSurface(tester, narrow, _formSheet(narrow));
      await _openSheet(tester);
      final sheet = tester.getRect(_panel);
      final header = tester.getRect(find.byType(AppSheetHeader));
      // 320/390 is below the 0.85 floor.
      expect(header.left - sheet.left, moreOrLessEquals(Insets.x4 * 0.85));
    });
  });

  group('AppSheetHeader', () {
    testOnEverySurface(
      'a very long title keeps the close button in view',
      (s) => AppSheetHeader(
        title: '${LongText.of(s)} ${LongText.of(s)} ${LongText.of(s)}',
      ),
      verify: (tester, s) async {
        final title = tester.widget<Text>(
          find.descendant(
            of: find.byType(AppSheetHeader),
            matching: find.byType(Text),
          ),
        );
        expect(title.maxLines, 2);
        expect(title.overflow, TextOverflow.ellipsis);
        final close = tester.getRect(_close);
        expect(close.left, greaterThanOrEqualTo(0));
        expect(close.right, lessThanOrEqualTo(s.size.width));
      },
    );

    testOnEverySurface(
      'a single unbreakable word ellipsizes instead of overflowing',
      (s) => AppSheetHeader(title: 'x' * 400),
    );

    testWidgets('the close button has a localized tooltip and a 48dp target', (
      tester,
    ) async {
      for (final s in [phoneEn, phoneAr]) {
        await pumpSurface(tester, s, const AppSheetHeader(title: 'T'));
        expect(
          find.byTooltip(l10n(s.locale).commonClose),
          findsOneWidget,
          reason: '$s',
        );
        final size = tester.getSize(_close);
        expect(size.width, greaterThanOrEqualTo(kMinInteractiveDimension));
        expect(size.height, greaterThanOrEqualTo(kMinInteractiveDimension));
      }
      expect(l10n(arabic).commonClose, 'إغلاق');
    });

    testWidgets('the close button sits at the end of the row', (tester) async {
      for (final s in [phoneEn, phoneAr]) {
        await pumpSurface(tester, s, const AppSheetHeader(title: 'Title'));
        final close = tester.getCenter(_close).dx;
        final title = tester.getCenter(find.text('Title')).dx;
        if (s.isArabic) {
          expect(close, lessThan(title), reason: 'RTL: close on the left');
        } else {
          expect(close, greaterThan(title), reason: 'LTR: close on the right');
        }
      }
    });

    testWidgets('directional padding mirrors in Arabic', (tester) async {
      const pad = EdgeInsetsDirectional.fromSTEB(24, 0, 8, 0);
      for (final s in [phoneEn, phoneAr]) {
        await pumpSurface(
          tester,
          s,
          const AppSheetHeader(title: 'Title', padding: pad),
        );
        final header = tester.getRect(find.byType(AppSheetHeader));
        final close = tester.getRect(_close);
        if (s.isArabic) {
          expect(close.left - header.left, 8);
        } else {
          expect(header.right - close.right, 8);
        }
      }
    });

    testWidgets('close with nothing to pop is harmless', (tester) async {
      await pumpSurface(tester, phoneEn, const AppSheetHeader(title: 'T'));
      await tester.tap(_close);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AppSheetHeader), findsOneWidget);
    });

    testWidgets('close pops the route it sits in, once', (tester) async {
      final popped = <Object?>[];
      await pumpSurface(
        tester,
        phoneEn,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              popped.add(
                await Navigator.of(context).push<Object>(
                  MaterialPageRoute(
                    builder: (_) => const Scaffold(
                      body: SafeArea(child: AppSheetHeader(title: 'Page')),
                    ),
                  ),
                ),
              );
            },
            child: const Text(_open),
          ),
        ),
      );
      await _openSheet(tester);
      expect(find.text('Page'), findsOneWidget);
      await tester.tap(_close);
      await tester.pumpAndSettle();
      expect(find.text('Page'), findsNothing);
      expect(find.text(_open), findsOneWidget);
      expect(popped, [null]);
    });

    testWidgets('the title uses the bold titleMedium style', (tester) async {
      for (final s in [phoneEn, surfaces[2]]) {
        await pumpSurface(tester, s, const AppSheetHeader(title: 'Title'));
        final theme = Theme.of(tester.element(find.text('Title')));
        final style = tester.widget<Text>(find.text('Title')).style!;
        expect(style.fontWeight, FontWeight.w700);
        expect(style.fontSize, theme.textTheme.titleMedium!.fontSize);
        expect(style.color, theme.textTheme.titleMedium!.color);
      }
    });

    testWidgets('an empty title still lays out', (tester) async {
      await pumpSurface(tester, phoneEn, const AppSheetHeader(title: ''));
      expectCleanLayout(tester);
      expect(_close, findsOneWidget);
    });
  });
}
