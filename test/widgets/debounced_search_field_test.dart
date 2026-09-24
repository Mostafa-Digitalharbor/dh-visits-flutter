import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/shared/widgets/debounced_search_field.dart';

import 'widget_harness.dart';

const _debounce = AppDurations.searchDebounce;
const _justBefore = Duration(milliseconds: 349);
const _tick = Duration(milliseconds: 1);

Finder get _field => find.byType(TextField);
Finder get _clearButton => find.byIcon(Icons.close);

String _clearTooltip(WidgetTester tester) =>
    MaterialLocalizations.of(tester.element(_field)).clearButtonTooltip;

/// Pumps a field on [surface] that records every reported query in [log].
Future<void> _pump(
  WidgetTester tester,
  List<String> log, {
  Surface surface = phoneEn,
  Duration debounce = _debounce,
  TextEditingController? controller,
  EdgeInsetsGeometry? padding,
  String? hint,
}) {
  final field = padding == null
      ? DebouncedSearchField(
          hintText: hint ?? l10n(surface.locale).customersSearchHint,
          onChanged: log.add,
          debounce: debounce,
          controller: controller,
        )
      : DebouncedSearchField(
          hintText: hint ?? l10n(surface.locale).customersSearchHint,
          onChanged: log.add,
          debounce: debounce,
          controller: controller,
          padding: padding,
        );
  return pumpSurface(tester, surface, field, settle: Duration.zero);
}

void main() {
  setUpAll(initHarness);

  group('DebouncedSearchField layout', () {
    testOnEverySurface(
      'a long hint fits on one line',
      (s) => DebouncedSearchField(hintText: LongText.of(s), onChanged: (_) {}),
      verify: (tester, s) async {
        expect(find.text(LongText.of(s)), findsOneWidget);
        expect(_clearButton, findsNothing);
      },
    );

    testOnEverySurface(
      'a long query with the clear button showing fits',
      (s) => Column(
        children: [
          DebouncedSearchField(
            hintText: l10n(s.locale).customersSearchHint,
            onChanged: (_) {},
          ),
          Expanded(
            child: ListView(
              children: [for (var i = 0; i < 30; i++) Text('row $i')],
            ),
          ),
        ],
      ),
      verify: (tester, s) async {
        await tester.enterText(_field, '${LongText.of(s)} ${LongText.of(s)}');
        await tester.pump();
        expect(_clearButton, findsOneWidget);
        // The clear button stays inside the field and on screen.
        final field = tester.getRect(_field);
        final clear = tester.getRect(find.byType(IconButton));
        expect(field.contains(clear.center), isTrue);
        expect(clear.right, lessThanOrEqualTo(s.size.width));
        await tester.pump(_debounce);
      },
    );
  });

  group('DebouncedSearchField debounce', () {
    testWidgets('reports the query once, only after the pause',
        (tester) async {
      final log = <String>[];
      await _pump(tester, log);
      await tester.enterText(_field, 'riyadh');
      await tester.pump(_justBefore);
      expect(log, isEmpty);
      await tester.pump(_tick);
      expect(log, ['riyadh']);
      // Nothing else is queued behind it.
      await tester.pump(const Duration(seconds: 2));
      expect(log, ['riyadh']);
    });

    testWidgets('each keystroke restarts the wait; only the last query is sent',
        (tester) async {
      final log = <String>[];
      await _pump(tester, log);
      for (final text in ['r', 'ri', 'riy', 'riya']) {
        await tester.enterText(_field, text);
        await tester.pump(const Duration(milliseconds: 300));
      }
      // 1.2s of typing, never a 350ms gap: nothing has been sent.
      expect(log, isEmpty);
      await tester.pump(const Duration(milliseconds: 49));
      expect(log, isEmpty);
      await tester.pump(_tick);
      expect(log, ['riya']);
    });

    testWidgets('two separate pauses report two queries in order',
        (tester) async {
      final log = <String>[];
      await _pump(tester, log);
      await tester.enterText(_field, 'a');
      await tester.pump(_debounce);
      await tester.enterText(_field, 'ab');
      await tester.pump(_debounce);
      expect(log, ['a', 'ab']);
    });

    testWidgets('the query is trimmed; blank input reports an empty query',
        (tester) async {
      final log = <String>[];
      await _pump(tester, log);
      await tester.enterText(_field, '  شركة الخليج  ');
      await tester.pump(_debounce);
      await tester.enterText(_field, '   ');
      await tester.pump(_debounce);
      expect(log, ['شركة الخليج', '']);
      // The field itself keeps what was typed.
      expect(tester.widget<TextField>(_field).controller!.text, '   ');
    });

    testWidgets('honours a custom debounce', (tester) async {
      final log = <String>[];
      await _pump(tester, log, debounce: const Duration(milliseconds: 50));
      await tester.enterText(_field, 'x');
      await tester.pump(const Duration(milliseconds: 49));
      expect(log, isEmpty);
      await tester.pump(_tick);
      expect(log, ['x']);
    });

    testWidgets('a parent rebuild keeps the pending query and its new callback '
        'receives it', (tester) async {
      final first = <String>[];
      final second = <String>[];
      await _pump(tester, first);
      await tester.enterText(_field, 'dammam');
      await tester.pump(const Duration(milliseconds: 200));
      // Same tree shape, new callback: the State (and its timer) survive.
      await _pump(tester, second);
      await tester.pump(const Duration(milliseconds: 150));
      expect(first, isEmpty);
      expect(second, ['dammam']);
    });

    testWidgets('disposing the field cancels the pending query',
        (tester) async {
      final log = <String>[];
      await _pump(tester, log);
      await tester.enterText(_field, 'jeddah');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(log, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('DebouncedSearchField clear button', () {
    testWidgets('appears only while there is text', (tester) async {
      final log = <String>[];
      await _pump(tester, log);
      expect(_clearButton, findsNothing);
      await tester.enterText(_field, 'a');
      await tester.pump();
      expect(_clearButton, findsOneWidget);
      await tester.enterText(_field, '');
      await tester.pump();
      expect(_clearButton, findsNothing);
      await tester.pump(_debounce);
      expect(log, ['']);
    });

    testWidgets('clears the text and reports "" at once, exactly once',
        (tester) async {
      final log = <String>[];
      await _pump(tester, log);
      await tester.enterText(_field, 'abha');
      await tester.pump();
      await tester.tap(_clearButton);
      await tester.pump();
      expect(log, ['']);
      expect(tester.widget<TextField>(_field).controller!.text, isEmpty);
      expect(_clearButton, findsNothing);
      // The query typed before the clear never arrives late.
      await tester.pump(const Duration(seconds: 2));
      expect(log, ['']);
    });

    testWidgets('after a query was sent, clear reports the reset',
        (tester) async {
      final log = <String>[];
      await _pump(tester, log);
      await tester.enterText(_field, 'abha');
      await tester.pump(_debounce);
      await tester.tap(_clearButton);
      await tester.pump(_debounce);
      expect(log, ['abha', '']);
    });

    for (final s in [phoneEn, phoneAr]) {
      testWidgets('has the platform "Clear text" tooltip and a 48dp target — $s',
          (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, [], surface: s);
        await tester.enterText(_field, 'x');
        await tester.pump();
        final tooltip = _clearTooltip(tester);
        expect(tooltip, isNotEmpty);
        expect(find.byTooltip(tooltip), findsOneWidget);
        final size = tester.getSize(find.byType(IconButton));
        expect(size.width, greaterThanOrEqualTo(IconSz.hit));
        expect(size.height, greaterThanOrEqualTo(IconSz.hit));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await tester.pump(_debounce);
        handle.dispose();
      });
    }

    testWidgets('the tooltip is localized', (tester) async {
      await _pump(tester, []);
      final en = _clearTooltip(tester);
      await _pump(tester, [], surface: phoneAr);
      final ar = _clearTooltip(tester);
      expect(en, 'Clear text');
      expect(ar, isNot(en));
    });
  });

  group('DebouncedSearchField controller', () {
    testWidgets('an owner controller sees the text and the clear',
        (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final log = <String>[];
      await _pump(tester, log, controller: controller);
      await tester.enterText(_field, 'tabuk');
      expect(controller.text, 'tabuk');
      await tester.pump();
      await tester.tap(_clearButton);
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(log, ['']);
    });

    testWidgets('text set by the owner shows the clear button without a query',
        (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final log = <String>[];
      await _pump(tester, log, controller: controller);
      controller.text = 'restored';
      await tester.pump();
      expect(find.text('restored'), findsOneWidget);
      expect(_clearButton, findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(log, isEmpty);
    });

    testWidgets('an owner controller is not disposed with the field',
        (tester) async {
      final controller = TextEditingController(text: 'kept');
      addTearDown(controller.dispose);
      await _pump(tester, [], controller: controller);
      await tester.pumpWidget(const SizedBox());
      // A disposed ChangeNotifier throws on addListener.
      expect(() => controller.addListener(() {}), returnsNormally);
      expect(controller.text, 'kept');
    });
  });

  group('DebouncedSearchField localization and direction', () {
    for (final s in [phoneEn, phoneAr]) {
      testWidgets('shows the localized hint — $s', (tester) async {
        await _pump(tester, [], surface: s);
        expect(find.text(l10n(s.locale).customersSearchHint), findsOneWidget);
        final field = tester.widget<TextField>(_field);
        expect(field.textInputAction, TextInputAction.search);
      });
    }

    testWidgets('the search glyph sits at the reading start', (tester) async {
      await _pump(tester, []);
      final enIcon = tester.getCenter(find.byIcon(Icons.search)).dx;
      final enField = tester.getCenter(_field).dx;
      await _pump(tester, [], surface: phoneAr);
      final arIcon = tester.getCenter(find.byIcon(Icons.search)).dx;
      final arField = tester.getCenter(_field).dx;
      expect(enIcon, lessThan(enField));
      expect(arIcon, greaterThan(arField));
    });

    testWidgets('the clear button sits at the reading end', (tester) async {
      await _pump(tester, [], surface: phoneAr);
      await tester.enterText(_field, 'x');
      await tester.pump();
      expect(tester.getCenter(_clearButton).dx,
          lessThan(tester.getCenter(_field).dx));
      await tester.pump(_debounce);
    });

    testWidgets('directional padding follows the reading direction',
        (tester) async {
      const padding = EdgeInsetsDirectional.fromSTEB(40, 10, 4, 20);
      // phoneEn/phoneAr are 390×844, the design canvas: r()/rh() are 1:1.
      await _pump(tester, [], padding: padding);
      final en = tester.getRect(_field);
      expect(en.left, 40);
      expect(en.right, phoneEn.size.width - 4);
      expect(en.top, 10);

      await _pump(tester, [], surface: phoneAr, padding: padding);
      final ar = tester.getRect(_field);
      expect(ar.left, 4);
      expect(ar.right, phoneAr.size.width - 40);
    });

    testWidgets('padding scales with a small screen', (tester) async {
      const small = Surface('small', size: Size(320, 568), locale: english);
      await _pump(tester, [], surface: small);
      // Default start padding 16 × 0.85 on a 320dp screen.
      expect(tester.getRect(_field).left, moreOrLessEquals(16 * 0.85));
    });
  });
}
