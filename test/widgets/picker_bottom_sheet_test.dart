import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/core/api/api_exceptions.dart';
import 'package:location_gps/shared/widgets/empty_view.dart';
import 'package:location_gps/shared/widgets/error_view.dart';
import 'package:location_gps/shared/widgets/picker_bottom_sheet.dart';
import 'package:location_gps/shared/widgets/skeleton.dart';

import 'widget_harness.dart';

class _Item {
  final int id;
  final String name;
  const _Item(this.id, this.name);
}

/// Records every query and answers with [respond].
class _Loader {
  _Loader([Future<List<_Item>> Function(String? q)? respond])
      : respond = respond ?? ((_) async => _items(3));

  final List<String?> calls = [];
  Future<List<_Item>> Function(String? q) respond;

  Future<List<_Item>> call(String? q) {
    calls.add(q);
    return respond(q);
  }
}

List<_Item> _items(int n, {String prefix = 'Project'}) =>
    [for (var i = 1; i <= n; i++) _Item(i, '$prefix $i')];

/// Opens the picker from a real route and reports what it returned.
class _Launcher extends StatelessWidget {
  final Surface surface;
  final _Loader loader;
  final void Function(_Item? result) onResult;
  final String? title;

  const _Launcher(this.surface, this.loader, this.onResult, {this.title});

  @override
  Widget build(BuildContext context) {
    final t = l10n(surface.locale);
    return Center(
      child: TextButton(
        onPressed: () async => onResult(await showPickerBottomSheet<_Item>(
          context: context,
          title: title ?? t.wfPickProject,
          searchHint: t.commonSearch,
          loader: loader.call,
          itemBuilder: (ctx, item) => ListTile(
            title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () => Navigator.pop(ctx, item),
          ),
        )),
        child: const Text('open'),
      ),
    );
  }
}

/// The sheet's entry animation, pumped in fixed steps: its loading skeleton
/// shimmers and its empty state pulses, so it never "settles".
Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _closeAnimation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<({_Loader loader, List<_Item?> results})> _pumpPicker(
  WidgetTester tester, {
  Surface surface = phoneEn,
  _Loader? loader,
  String? title,
}) async {
  final l = loader ?? _Loader();
  final results = <_Item?>[];
  await pumpSurface(
    tester,
    surface,
    _Launcher(surface, l, results.add, title: title),
  );
  await _open(tester);
  return (loader: l, results: results);
}

void main() {
  setUpAll(initHarness);

  group('Picker layout', () {
    testOnEverySurface(
      'a long title and long results fit',
      (s) => _Launcher(
        s,
        _Loader((_) async => [
              for (var i = 0; i < 30; i++) _Item(i, '${LongText.of(s)} $i'),
            ]),
        (_) {},
        title: LongText.of(s),
      ),
      verify: (tester, s) async {
        await _open(tester);
        final t = l10n(s.locale);
        expect(find.text(LongText.of(s)), findsOneWidget);
        expect(find.text(t.commonSearch), findsOneWidget);
        expect(find.byTooltip(t.commonClose), findsOneWidget);
        expect(find.byType(ListTile), findsWidgets);
      },
    );

    for (final surface in surfaces) {
      testWidgets('lifts above the keyboard and shrinks to fit — $surface',
          (tester) async {
        final keyboard = surface.size.height > 400 ? 300.0 : 200.0;
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
        await _pumpPicker(
          tester,
          surface: surface,
          loader: _Loader((_) async => _items(40)),
        );
        expectCleanLayout(tester);
        final sheet = tester.getRect(find.byType(CustomScrollView));
        expect(
          sheet.bottom,
          moreOrLessEquals(surface.size.height - keyboard),
          reason: 'results must not sit behind the keyboard',
        );
        expect(sheet.top, greaterThanOrEqualTo(0));
        final available = surface.size.height;
        expect(
          sheet.height,
          moreOrLessEquals(
            (available * 0.85).clamp(0, available - keyboard).toDouble(),
          ),
        );
      });
    }

    testWidgets('without a keyboard it takes 85% of the height',
        (tester) async {
      await _pumpPicker(tester);
      final sheet = tester.getRect(find.byType(CustomScrollView));
      expect(sheet.height, moreOrLessEquals(844 * 0.85));
      expect(sheet.bottom, 844);
    });

    testWidgets('the header stays pinned while results scroll',
        (tester) async {
      await _pumpPicker(tester, loader: _Loader((_) async => _items(60)));
      final t = l10n(english);
      final title = tester.getRect(find.text(t.wfPickProject));
      await tester.drag(find.text('Project 5'), const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Project 1'), findsNothing);
      expect(tester.getRect(find.text(t.wfPickProject)), title);
      expect(find.text(t.commonSearch), findsOneWidget);
    });

    testWidgets('an Arabic sheet mirrors: title at the right, close at the left',
        (tester) async {
      await _pumpPicker(tester, surface: phoneAr);
      final t = l10n(arabic);
      final title = tester.getCenter(find.text(t.wfPickProject));
      final close = tester.getCenter(find.byTooltip(t.commonClose));
      expect(close.dx, lessThan(title.dx));
    });
  });

  group('Picker loading', () {
    testWidgets('loads everything first, with a null query', (tester) async {
      final (:loader, results: _) = await _pumpPicker(tester);
      expect(loader.calls, [null]);
      expect(find.text('Project 1'), findsOneWidget);
      expect(find.text('Project 3'), findsOneWidget);
    });

    testWidgets('re-queries only after the debounce', (tester) async {
      final (:loader, results: _) = await _pumpPicker(
        tester,
        loader: _Loader((q) async => _items(2, prefix: q ?? 'Project')),
      );
      await tester.enterText(find.byType(TextField), 'Acme');
      await tester.pump(AppDurations.pickerDebounce -
          const Duration(milliseconds: 1));
      expect(loader.calls, [null]);

      await tester.pump(const Duration(milliseconds: 1));
      expect(loader.calls, [null, 'Acme']);
      await tester.pump();
      await tester.pump();
      expect(find.text('Acme 1'), findsOneWidget);
      expect(find.text('Project 1'), findsNothing);
    });

    testWidgets('fast typing sends one query, for the final text',
        (tester) async {
      final (:loader, results: _) = await _pumpPicker(tester);
      for (final text in ['A', 'Ac', 'Acm', 'Acme']) {
        await tester.enterText(find.byType(TextField), text);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(AppDurations.pickerDebounce);
      expect(loader.calls, [null, 'Acme']);
    });

    testWidgets('the query is trimmed; blank means everything',
        (tester) async {
      final (:loader, results: _) = await _pumpPicker(tester);
      await tester.enterText(find.byType(TextField), '  Acme  ');
      await tester.pump(AppDurations.pickerDebounce);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump(AppDurations.pickerDebounce);
      expect(loader.calls, [null, 'Acme', null]);
    });

    testWidgets('clearing the field reloads everything at once',
        (tester) async {
      final (:loader, results: _) = await _pumpPicker(tester);
      await tester.enterText(find.byType(TextField), 'Acme');
      await tester.pump(AppDurations.pickerDebounce);
      final clear = find.byTooltip(
        MaterialLocalizations.of(tester.element(find.byType(TextField)))
            .clearButtonTooltip,
      );
      await tester.tap(clear);
      await tester.pump();
      expect(loader.calls, [null, 'Acme', null]);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty);
    });

    testWidgets('a skeleton shows while loading, then the results',
        (tester) async {
      final pending = Completer<List<_Item>>();
      await _pumpPicker(tester, loader: _Loader((_) => pending.future));
      expect(find.byType(SkeletonList), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);

      pending.complete(_items(2));
      await tester.pump();
      expect(find.byType(SkeletonList), findsNothing);
      expect(find.text('Project 2'), findsOneWidget);
    });

    testWidgets('a slow answer to an old query never replaces a newer one',
        (tester) async {
      final slow = Completer<List<_Item>>();
      final (:loader, results: _) = await _pumpPicker(
        tester,
        loader: _Loader((q) => q == 'A'
            ? slow.future
            : Future.value(_items(1, prefix: q ?? 'Project'))),
      );
      await tester.enterText(find.byType(TextField), 'A');
      await tester.pump(AppDurations.pickerDebounce);
      await tester.enterText(find.byType(TextField), 'AB');
      await tester.pump(AppDurations.pickerDebounce);
      await tester.pump();
      expect(find.text('AB 1'), findsOneWidget);

      slow.complete(_items(1, prefix: 'A'));
      await tester.pump();
      expect(find.text('A 1'), findsNothing);
      expect(find.text('AB 1'), findsOneWidget);
      expect(loader.calls, [null, 'A', 'AB']);
    });

    for (final surface in [phoneEn, phoneAr]) {
      testWidgets('no results shows the localized empty state — $surface',
          (tester) async {
        await _pumpPicker(
          tester,
          surface: surface,
          loader: _Loader((_) async => const []),
        );
        expect(find.byType(EmptyView), findsOneWidget);
        expect(
          find.text(l10n(surface.locale).pickerNoResults),
          findsOneWidget,
        );
        expectCleanLayout(tester);
      });
    }
  });

  group('Picker errors', () {
    for (final surface in [phoneEn, surfaces[2]]) {
      testWidgets('a refused source explains itself, no code — $surface',
          (tester) async {
        final t = l10n(surface.locale);
        await _pumpPicker(
          tester,
          surface: surface,
          loader: _Loader(
              (_) async => throw ApiException(code: ApiErrorCode.permissionDenied)),
        );
        expectCleanLayout(tester);
        expect(find.byType(ErrorView), findsOneWidget);
        expect(find.text(t.errPermissionDenied), findsOneWidget);
        expect(find.textContaining(t.commonErrorReference('')), findsNothing);
      });

      testWidgets('an unexpected failure never shows raw text — $surface',
          (tester) async {
        final t = l10n(surface.locale);
        await _pumpPicker(
          tester,
          surface: surface,
          loader: _Loader((_) async => throw StateError('socket closed #42')),
        );
        expectCleanLayout(tester);
        expect(find.text(t.errUnknown), findsOneWidget);
        expect(find.text(t.commonErrorReference('unknown')), findsOneWidget);
        expect(find.textContaining('socket closed'), findsNothing);
      });
    }

    testWidgets('a server failure carries its support code', (tester) async {
      await _pumpPicker(
        tester,
        loader: _Loader(
            (_) async => throw ApiException(code: ApiErrorCode.server)),
      );
      expect(
        find.text(l10n(english).commonErrorReference('server')),
        findsOneWidget,
      );
    });

    testWidgets('retry repeats the current query', (tester) async {
      var fail = true;
      final loader = _Loader((q) async {
        if (fail) throw ApiException(code: ApiErrorCode.network);
        return _items(1, prefix: q ?? 'Project');
      });
      await _pumpPicker(tester, loader: loader);
      await tester.enterText(find.byType(TextField), ' Acme ');
      await tester.pump(AppDurations.pickerDebounce);
      await tester.pump();
      expect(find.byType(ErrorView), findsOneWidget);

      fail = false;
      await tester.tap(find.text(l10n(english).commonRetry));
      await tester.pump();
      await tester.pump();
      expect(loader.calls, [null, 'Acme', 'Acme']);
      expect(find.text('Acme 1'), findsOneWidget);
    });

    testWidgets('retry with an empty field reloads everything',
        (tester) async {
      var fail = true;
      final loader = _Loader((_) async {
        if (fail) throw ApiException(code: ApiErrorCode.timeout);
        return _items(2);
      });
      await _pumpPicker(tester, loader: loader);
      fail = false;
      await tester.tap(find.text(l10n(english).commonRetry));
      await tester.pump();
      await tester.pump();
      expect(loader.calls, [null, null]);
      expect(find.text('Project 2'), findsOneWidget);
    });
  });

  group('Picker result', () {
    testWidgets('choosing an item closes the sheet and returns it',
        (tester) async {
      final (loader: _, :results) = await _pumpPicker(tester);
      await tester.tap(find.text('Project 2'));
      await _closeAnimation(tester);
      expect(find.byType(CustomScrollView), findsNothing);
      expect(results, hasLength(1));
      expect(results.single!.id, 2);
    });

    testWidgets('the close button returns null', (tester) async {
      final (loader: _, :results) = await _pumpPicker(tester, surface: phoneAr);
      await tester.tap(find.byTooltip(l10n(arabic).commonClose));
      await _closeAnimation(tester);
      expect(find.byType(CustomScrollView), findsNothing);
      expect(results, [null]);
    });

    testWidgets('tapping the scrim returns null', (tester) async {
      final (loader: _, :results) = await _pumpPicker(tester);
      await tester.tapAt(const Offset(20, 20));
      await _closeAnimation(tester);
      expect(results, [null]);
    });

    testWidgets('a sheet gone before the debounce sends no late query',
        (tester) async {
      final (:loader, :results) = await _pumpPicker(tester);
      await tester.enterText(find.byType(TextField), 'Acme');
      await tester.tap(find.byTooltip(l10n(english).commonClose));
      // The exit animation (200ms) ends and the route is disposed before the
      // 300ms debounce would fire; disposing cancels the timer.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
      await tester.pump(AppDurations.pickerDebounce * 2);
      expect(loader.calls, [null]);
      expect(results, [null]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an answer landing after close is ignored', (tester) async {
      final pending = Completer<List<_Item>>();
      final (loader: _, :results) =
          await _pumpPicker(tester, loader: _Loader((_) => pending.future));
      await tester.tap(find.byTooltip(l10n(english).commonClose));
      await _closeAnimation(tester);
      pending.complete(_items(1));
      await tester.pump();
      expect(results, [null]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the sheet can be opened again after closing',
        (tester) async {
      final (:loader, :results) = await _pumpPicker(tester);
      await tester.tap(find.byTooltip(l10n(english).commonClose));
      await _closeAnimation(tester);
      await _open(tester);
      await tester.tap(find.text('Project 3'));
      await _closeAnimation(tester);
      expect(results.map((r) => r?.id), [null, 3]);
      expect(loader.calls, [null, null]);
    });
  });
}
