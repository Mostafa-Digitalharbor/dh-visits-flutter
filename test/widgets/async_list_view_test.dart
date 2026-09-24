import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/core/api/api_error_messages.dart';
import 'package:location_gps/core/api/api_exceptions.dart';
import 'package:location_gps/core/constants.dart';
import 'package:location_gps/shared/widgets/animated_list_item.dart';
import 'package:location_gps/shared/widgets/app_refresh_indicator.dart';
import 'package:location_gps/shared/widgets/async_list_view.dart';
import 'package:location_gps/shared/widgets/empty_view.dart';
import 'package:location_gps/shared/widgets/error_view.dart';
import 'package:location_gps/shared/widgets/skeleton.dart';

import 'widget_harness.dart';

typedef _Row = ({int id, String name});

List<_Row> _rows(int n, [String name = 'Customer']) => [
  for (var i = 0; i < n; i++) (id: i, name: '$name $i'),
];

Key _rowKey(int i) => ValueKey('row-$i');

/// Builds the list with test-friendly defaults; every row records the index
/// it was built with.
Widget _list({
  List<_Row> items = const [],
  bool isLoading = false,
  bool hasError = false,
  String? errorMessage,
  ApiException? error,
  Future<void> Function()? onRefresh,
  String emptyMessage = 'Nothing here',
  IconData emptyIcon = Icons.inbox_outlined,
  int skeletonCount = AsyncListView.defaultSkeletonCount,
  EdgeInsetsGeometry? padding,
  double separatorHeight = 8,
  Map<int, int>? builtIndices,
}) {
  Widget row(BuildContext context, _Row item, int index) {
    builtIndices?[item.id] = index;
    return ListTile(key: _rowKey(item.id), title: Text(item.name));
  }

  return padding == null
      ? AsyncListView<_Row>(
          items: items,
          isLoading: isLoading,
          hasError: hasError,
          errorMessage: errorMessage,
          error: error,
          onRefresh: onRefresh ?? () async {},
          itemBuilder: row,
          emptyMessage: emptyMessage,
          emptyIcon: emptyIcon,
          skeletonCount: skeletonCount,
          separatorHeight: separatorHeight,
        )
      : AsyncListView<_Row>(
          items: items,
          isLoading: isLoading,
          hasError: hasError,
          errorMessage: errorMessage,
          error: error,
          onRefresh: onRefresh ?? () async {},
          itemBuilder: row,
          emptyMessage: emptyMessage,
          emptyIcon: emptyIcon,
          skeletonCount: skeletonCount,
          padding: padding,
          separatorHeight: separatorHeight,
        );
}

Finder get _skeleton => find.byKey(WidgetKeys.listSkeleton);
Finder get _empty => find.byKey(WidgetKeys.listEmpty);
Finder get _content => find.byKey(WidgetKeys.listContent);

/// Past the state cross-fade and the first rows' entrance, without waiting
/// on the (endless) skeleton shimmer.
Future<void> _settle(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 1));

/// Jumps the list's scroll view to its end until [target] is built. Lazy
/// lists only estimate their extent, so this may take a few jumps.
Future<void> _jumpUntilBuilt(WidgetTester tester, Finder target) async {
  final position = tester
      .state<ScrollableState>(
        find.descendant(of: _content, matching: find.byType(Scrollable)).first,
      )
      .position;
  for (var i = 0; i < 20 && target.evaluate().isEmpty; i++) {
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
  }
}

/// Pulls down far enough to trigger a refresh, scaled to the viewport.
Future<void> _pull(WidgetTester tester, Finder target) async {
  final height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  await tester.fling(target, Offset(0, height * 0.6), 1000);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(initHarness);

  group('AsyncListView layout', () {
    testOnEverySurface(
      'loading shows the skeleton without overflow',
      (s) => _list(isLoading: true),
      verify: (tester, s) async {
        expect(_skeleton, findsOneWidget);
      },
    );

    testOnEverySurface(
      'an empty list shows a long localized message',
      (s) => _list(
        emptyMessage: '${l10n(s.locale).customersEmpty} ${LongText.of(s)}',
      ),
      verify: (tester, s) async {
        await tester.pumpAndSettle();
        expect(_empty, findsOneWidget);
        expect(
          find.textContaining(l10n(s.locale).customersEmpty),
          findsOneWidget,
        );
      },
    );

    testOnEverySurface(
      'a failure shows the message, the reference and a reachable retry',
      (s) => _list(
        hasError: true,
        errorMessage: '${l10n(s.locale).errServerError} ${LongText.of(s)}',
        error: ApiException(code: ApiErrorCode.server),
      ),
      verify: (tester, s) async {
        expect(find.byType(ErrorView), findsOneWidget);
        final retry = find.text(l10n(s.locale).commonRetry);
        await tester.scrollUntilVisible(
          retry,
          60,
          scrollable: find.byType(Scrollable).first,
        );
        expect(retry.hitTestable(), findsOneWidget);
      },
    );

    testOnEverySurface(
      'many long rows scroll',
      (s) => AsyncListView<String>(
        items: [for (var i = 0; i < 60; i++) '${LongText.of(s)} #$i'],
        isLoading: false,
        hasError: false,
        errorMessage: null,
        onRefresh: () async {},
        emptyMessage: '',
        itemBuilder: (_, item, i) => ListTile(
          leading: const Icon(Icons.store_mall_directory_outlined),
          title: Text(item),
          subtitle: Text(LongText.arabicPerson),
        ),
      ),
      verify: (tester, s) async {
        await _settle(tester);
        expect(_content, findsOneWidget);
        await _jumpUntilBuilt(tester, find.textContaining('#59'));
        expect(find.textContaining('#59'), findsOneWidget);
      },
    );
  });

  group('AsyncListView states', () {
    testWidgets('first load: a skeleton with the requested row count', (
      tester,
    ) async {
      await pumpSurface(tester, phoneEn, _list(isLoading: true));
      expect(_skeleton, findsOneWidget);
      expect(
        tester.widget<SkeletonList>(_skeleton).itemCount,
        AsyncListView.defaultSkeletonCount,
      );
      expect(find.byType(EmptyView), findsNothing);
      expect(find.byType(ErrorView), findsNothing);

      await pumpSurface(
        tester,
        phoneEn,
        _list(isLoading: true, skeletonCount: 3),
      );
      await _settle(tester);
      expect(tester.widget<SkeletonList>(_skeleton).itemCount, 3);
    });

    testWidgets('refreshing over existing rows keeps showing them', (
      tester,
    ) async {
      await pumpSurface(
        tester,
        phoneEn,
        _list(isLoading: true, items: _rows(3)),
      );
      expect(_content, findsOneWidget);
      expect(_skeleton, findsNothing);
      expect(find.byKey(_rowKey(2)), findsOneWidget);
    });

    testWidgets('empty: the message and the icon', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        _list(emptyMessage: 'No customers', emptyIcon: Icons.people_outline),
      );
      await tester.pumpAndSettle();
      expect(_empty, findsOneWidget);
      final empty = tester.widget<EmptyView>(find.byType(EmptyView));
      expect(empty.message, 'No customers');
      expect(empty.icon, Icons.people_outline);
      expect(find.text('No customers'), findsOneWidget);
      expect(find.byIcon(Icons.people_outline), findsOneWidget);
      expect(_content, findsNothing);
    });

    testWidgets('empty uses the inbox icon by default', (tester) async {
      await pumpSurface(tester, phoneEn, _list());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });

    testWidgets('list: every item, in order, with its index', (tester) async {
      final built = <int, int>{};
      await pumpSurface(
        tester,
        phoneEn,
        _list(items: _rows(5), builtIndices: built),
      );
      await _settle(tester);
      expect(_content, findsOneWidget);
      expect(built, {0: 0, 1: 1, 2: 2, 3: 3, 4: 4});
      for (var i = 1; i < 5; i++) {
        expect(
          tester.getTopLeft(find.byKey(_rowKey(i))).dy,
          greaterThan(tester.getTopLeft(find.byKey(_rowKey(i - 1))).dy),
        );
      }
      // Rows cascade in.
      expect(
        find.ancestor(
          of: find.byKey(_rowKey(0)),
          matching: find.byType(AnimatedListItem),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a huge list builds lazily and reaches the end', (
      tester,
    ) async {
      final built = <int, int>{};
      await pumpSurface(
        tester,
        phoneEn,
        _list(items: _rows(1000), builtIndices: built),
      );
      await _settle(tester);
      expect(built.length, lessThan(40));
      await _jumpUntilBuilt(tester, find.text('Customer 999'));
      expect(find.text('Customer 999'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AsyncListView failures', () {
    testWidgets('failure beats loading and empty', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        _list(isLoading: true, hasError: true, errorMessage: 'Boom'),
      );
      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.text('Boom'), findsOneWidget);
      expect(_skeleton, findsNothing);
      expect(_empty, findsNothing);
    });

    testWidgets('a failed refresh over existing rows keeps the rows', (
      tester,
    ) async {
      await pumpSurface(
        tester,
        phoneEn,
        _list(items: _rows(2), hasError: true, errorMessage: 'Boom'),
      );
      expect(find.byType(ErrorView), findsNothing);
      expect(find.text('Boom'), findsNothing);
      expect(find.byKey(_rowKey(1)), findsOneWidget);
    });

    testWidgets('retry calls onRefresh once per tap', (tester) async {
      var calls = 0;
      await pumpSurface(
        tester,
        phoneEn,
        _list(
          hasError: true,
          errorMessage: 'Boom',
          onRefresh: () async => calls++,
        ),
      );
      await tester.tap(find.text(l10n(english).commonRetry));
      await tester.pump();
      expect(calls, 1);
      await tester.tap(find.text(l10n(english).commonRetry));
      await tester.pump();
      expect(calls, 2);
    });

    for (final s in [phoneEn, phoneAr]) {
      final t = l10n(s.locale);

      testWidgets('no message and no error: the generic sentence — $s', (
        tester,
      ) async {
        await pumpSurface(tester, s, _list(hasError: true));
        expect(find.text(t.errUnknown), findsOneWidget);
        // Never an empty screen, never a support code without a failure.
        expect(find.textContaining(t.commonErrorReference('')), findsNothing);
      });

      testWidgets('no message: the error decides it, with a reference — $s', (
        tester,
      ) async {
        final error = ApiException(code: ApiErrorCode.server);
        await pumpSurface(tester, s, _list(hasError: true, error: error));
        expect(find.text(error.messageFor(t)), findsOneWidget);
        expect(find.text(t.errServerError), findsOneWidget);
        expect(find.text(t.commonErrorReference('server')), findsOneWidget);
      });

      testWidgets('a network failure needs no support reference — $s', (
        tester,
      ) async {
        await pumpSurface(
          tester,
          s,
          _list(hasError: true, error: ApiException.network()),
        );
        expect(find.text(t.errNetworkUnreachable), findsOneWidget);
        expect(find.textContaining(t.commonErrorReference('')), findsNothing);
      });

      testWidgets('an English server sentence only reaches English — $s', (
        tester,
      ) async {
        const sentence = 'The customer record is archived.';
        await pumpSurface(
          tester,
          s,
          _list(
            hasError: true,
            error: ApiException(
              code: ApiErrorCode.validation,
              serverMessage: sentence,
            ),
          ),
        );
        if (s.isArabic) {
          expect(find.text(sentence), findsNothing);
          expect(find.text(t.errValidation), findsOneWidget);
        } else {
          expect(find.text(sentence), findsOneWidget);
        }
      });

      testWidgets('an explicit message wins, the reference stays — $s', (
        tester,
      ) async {
        await pumpSurface(
          tester,
          s,
          _list(
            hasError: true,
            errorMessage: t.errPermissionDenied,
            error: ApiException(code: ApiErrorCode.unknown),
          ),
        );
        expect(find.text(t.errPermissionDenied), findsOneWidget);
        expect(find.text(t.errUnknown), findsNothing);
        expect(find.text(t.commonErrorReference('unknown')), findsOneWidget);
        expect(find.text(t.commonRetry), findsOneWidget);
      });
    }
  });

  group('AsyncListView refresh', () {
    testWidgets('pulling the list calls onRefresh once', (tester) async {
      var calls = 0;
      final done = Completer<void>();
      await pumpSurface(
        tester,
        phoneEn,
        _list(
          items: _rows(30),
          onRefresh: () {
            calls++;
            return done.future;
          },
        ),
      );
      await _settle(tester);
      await _pull(tester, _content);
      expect(calls, 1);
      expect(find.byType(RefreshProgressIndicator), findsOneWidget);
      done.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // indicator hides
      expect(find.byType(RefreshProgressIndicator), findsNothing);
      await _pull(tester, _content);
      expect(calls, 2, reason: 'a finished refresh can be pulled again');
    });

    testWidgets('a short list can be pulled too', (tester) async {
      var calls = 0;
      await pumpSurface(
        tester,
        phoneEn,
        _list(items: _rows(1), onRefresh: () async => calls++),
      );
      await _settle(tester);
      await _pull(tester, _content);
      expect(calls, 1);
    });

    testWidgets('the empty state can be pulled to refresh', (tester) async {
      // "Nothing here" is exactly when a user pulls to check again.
      var calls = 0;
      await pumpSurface(
        tester,
        phoneEn,
        _list(emptyMessage: 'No visits today', onRefresh: () async => calls++),
      );
      await tester.pumpAndSettle();
      await _pull(tester, find.text('No visits today'));
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the empty state still scrolls when it overflows', (
      tester,
    ) async {
      const landscape = Surface(
        'landscape',
        size: Size(720, 360),
        locale: arabic,
        textScale: Responsive.maxTextScale,
      );
      var calls = 0;
      await pumpSurface(
        tester,
        landscape,
        _list(
          emptyMessage: List.filled(4, LongText.arabicCompany).join(' '),
          onRefresh: () async => calls++,
        ),
      );
      await tester.pumpAndSettle();
      expectCleanLayout(tester);
      final position = tester
          .state<ScrollableState>(
            find
                .descendant(of: _empty, matching: find.byType(Scrollable))
                .first,
          )
          .position;
      expect(position.maxScrollExtent, greaterThan(0));
      await tester.drag(_empty, const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(0));
      expect(calls, 0, reason: 'scrolling down is not a refresh');
    });

    testWidgets('the skeleton and the list sit under the refresh indicator; '
        'the error view offers retry instead', (tester) async {
      await pumpSurface(tester, phoneEn, _list(isLoading: true));
      expect(
        find.ancestor(
          of: _skeleton,
          matching: find.byType(AppRefreshIndicator),
        ),
        findsOneWidget,
      );

      await pumpSurface(tester, phoneEn, _list(items: _rows(2)));
      await _settle(tester);
      expect(
        find.ancestor(of: _content, matching: find.byType(AppRefreshIndicator)),
        findsOneWidget,
      );

      await pumpSurface(tester, phoneEn, _list(hasError: true));
      expect(find.byType(AppRefreshIndicator), findsNothing);
      expect(find.text(l10n(english).commonRetry), findsOneWidget);
    });
  });

  group('AsyncListView transitions and geometry', () {
    testWidgets('loading → list cross-fades and leaves only the list', (
      tester,
    ) async {
      await pumpSurface(
        tester,
        phoneEn,
        _list(isLoading: true),
        settle: Duration.zero,
      );
      await pumpSurface(
        tester,
        phoneEn,
        _list(items: _rows(3)),
        settle: const Duration(milliseconds: 100),
      );
      // Mid-switch both are present…
      expect(_skeleton, findsOneWidget);
      expect(_content, findsOneWidget);
      // …then the skeleton (and its endless shimmer) is gone.
      await tester.pump(const Duration(milliseconds: 300));
      expect(_skeleton, findsNothing);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('empty → list replaces the empty state', (tester) async {
      await pumpSurface(tester, phoneEn, _list());
      await tester.pumpAndSettle();
      expect(_empty, findsOneWidget);
      await pumpSurface(tester, phoneEn, _list(items: _rows(2)));
      await tester.pumpAndSettle();
      expect(_empty, findsNothing);
      expect(find.byKey(_rowKey(1)), findsOneWidget);
    });

    testWidgets('rows are separated by the design-space gap', (tester) async {
      Future<double> gap(double separator) async {
        await pumpSurface(
          tester,
          phoneEn,
          _list(items: _rows(2), separatorHeight: separator),
        );
        await tester.pumpAndSettle();
        return tester.getTopLeft(find.byKey(_rowKey(1))).dy -
            tester.getBottomLeft(find.byKey(_rowKey(0))).dy;
      }

      // 844dp tall is the design height, so rh() is the identity here.
      expect(await gap(8), moreOrLessEquals(8));
      expect(await gap(0), moreOrLessEquals(0));
      expect(await gap(24), moreOrLessEquals(24));
    });

    testWidgets('directional padding mirrors in Arabic', (tester) async {
      const padding = EdgeInsetsDirectional.fromSTEB(40, 10, 4, 0);
      for (final s in [phoneEn, phoneAr]) {
        await pumpSurface(tester, s, _list(items: _rows(1), padding: padding));
        await tester.pumpAndSettle();
        final row = tester.getRect(find.byKey(_rowKey(0)));
        expect(row.top, moreOrLessEquals(10), reason: '$s');
        if (s.isArabic) {
          expect(s.size.width - row.right, moreOrLessEquals(40));
          expect(row.left, moreOrLessEquals(4));
        } else {
          expect(row.left, moreOrLessEquals(40));
          expect(s.size.width - row.right, moreOrLessEquals(4));
        }
      }
    });

    testWidgets('padding scales with a narrow screen', (tester) async {
      const narrow = Surface('narrow', size: Size(320, 640), locale: english);
      await pumpSurface(
        tester,
        narrow,
        _list(
          items: _rows(1),
          padding: const EdgeInsetsDirectional.only(start: 40),
        ),
      );
      await tester.pumpAndSettle();
      // 320/390 is below the 0.85 floor.
      expect(
        tester.getTopLeft(find.byKey(_rowKey(0))).dx,
        moreOrLessEquals(40 * 0.85),
      );
    });
  });

  group('with a header', () {
    const headerKey = Key('header');
    Widget withHeader({
      List<_Row> items = const [],
      bool isLoading = false,
      bool hasError = false,
      Future<void> Function()? onRefresh,
    }) =>
        AsyncListView<_Row>(
          items: items,
          isLoading: isLoading,
          hasError: hasError,
          errorMessage: hasError ? 'Could not load' : null,
          onRefresh: onRefresh ?? () async {},
          emptyMessage: 'Nothing here',
          header: Container(
            key: headerKey,
            height: 140,
            color: Colors.blue,
          ),
          itemBuilder: (context, item, i) =>
              ListTile(key: _rowKey(item.id), title: Text(item.name)),
        );

    testWidgets('the header stays above every state', (tester) async {
      for (final state in [
        withHeader(isLoading: true),
        withHeader(hasError: true),
        withHeader(),
        withHeader(items: _rows(3)),
      ]) {
        await pumpSurface(tester, phoneEn, state);
        await tester.pump(const Duration(seconds: 1));
        expect(find.byKey(headerKey), findsOneWidget);
        expectCleanLayout(tester);
      }
      expect(find.byKey(_rowKey(0)), findsOneWidget);
    });

    testWidgets('the header scrolls away with the rows', (tester) async {
      await pumpSurface(tester, phoneEn, withHeader(items: _rows(40)));
      await tester.pump(const Duration(seconds: 1));
      final before = tester.getTopLeft(find.byKey(headerKey)).dy;
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -100));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.getTopLeft(find.byKey(headerKey)).dy, lessThan(before));
    });

    testWidgets('a short screen with the keyboard up does not overflow',
        (tester) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      for (final state in [
        withHeader(isLoading: true),
        withHeader(hasError: true),
        withHeader(),
        withHeader(items: _rows(5)),
      ]) {
        await pumpSurface(
          tester,
          const Surface('landscape', size: Size(720, 360), locale: arabic),
          state,
        );
        await tester.pump(const Duration(seconds: 1));
        expectCleanLayout(tester);
      }
    });

    testWidgets('the empty state can still be pulled to refresh',
        (tester) async {
      var refreshed = 0;
      await pumpSurface(
        tester,
        phoneEn,
        withHeader(onRefresh: () async => refreshed++),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.fling(
          find.byType(CustomScrollView), const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(refreshed, 1);
    });
  });
}
