import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/core/api/api_error_messages.dart';
import 'package:location_gps/core/api/api_exceptions.dart';
import 'package:location_gps/core/di/service_locator.dart';
import 'package:location_gps/core/network/connectivity_status.dart';
import 'package:location_gps/features/dashboard/view/visits_list_feedback.dart';
import 'package:location_gps/features/visits/bloc/visits_list_bloc.dart';
import 'package:location_gps/features/visits/data/models/visit.dart';
import 'package:location_gps/l10n/generated/app_localizations.dart';
import 'package:location_gps/shared/widgets/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../widgets/widget_harness.dart';
import '../feature_fakes.dart';

final _rows = [
  const Visit(id: 1, name: 'VIS/1'),
  const Visit(id: 2, name: 'VIS/2'),
];

VisitsListState _success([List<Visit>? items]) => VisitsListState(
      status: VisitsListStatus.success,
      items: items ?? _rows,
    );

VisitsListState _failure({
  List<Visit>? items,
  ApiException? error,
}) =>
    VisitsListState(
      status: VisitsListStatus.failure,
      items: items ?? _rows,
      error: error,
    );

final _offline = ApiException(code: ApiErrorCode.network);

String _staleMessage(AppLocalizations t, ApiException? error) =>
    t.commonRefreshFailedStale(error?.messageFor(t) ?? t.errUnknown);

void main() {
  setUpAll(initHarness);

  group('VisitsRefreshFailureListener', () {
    late StubListBloc bloc;

    setUp(() => bloc = StubListBloc(_success()));
    tearDown(() => bloc.close());

    Future<void> pumpListener(
      WidgetTester tester, {
      Surface surface = phoneEn,
      bool visible = true,
    }) =>
        pumpSurface(
          tester,
          surface,
          withBlocs(
            list: bloc,
            Visibility(
              visible: visible,
              maintainState: true,
              child: const VisitsRefreshFailureListener(
                child: Text('rows', key: Key('child')),
              ),
            ),
          ),
        );

    Future<void> emit(WidgetTester tester, VisitsListState state) async {
      bloc.push(state);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('renders its child untouched', (tester) async {
      await pumpListener(tester);
      expect(find.byKey(const Key('child')), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    for (final surface in const [phoneEn, phoneAr]) {
      testWidgets(
          'a failed refresh over rows says so, localized — ${surface.name}',
          (tester) async {
        await pumpListener(tester, surface: surface);
        await emit(tester, _failure(error: _offline));
        final t = l10n(surface.locale);
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text(_staleMessage(t, _offline)), findsOneWidget);
        // The rows stay: nothing blanks the screen.
        expect(find.byKey(const Key('child')), findsOneWidget);
      });
    }

    testWidgets('it is an error snack', (tester) async {
      await pumpListener(tester);
      await emit(tester, _failure(error: _offline));
      final snack = tester.widget<SnackBar>(find.byType(SnackBar));
      final context = tester.element(find.byKey(const Key('child')));
      expect(snack.backgroundColor, Theme.of(context).colorScheme.error);
      expect(snack.showCloseIcon, isTrue);
    });

    group('while the device is offline', () {
      late ConnectivityStatus connectivity;
      setUp(() {
        connectivity = ConnectivityStatus()..markOffline();
        sl.registerSingleton<ConnectivityStatus>(connectivity);
      });
      tearDown(() => sl.unregister<ConnectivityStatus>());

      for (final code in [ApiErrorCode.network, ApiErrorCode.timeout]) {
        testWidgets('a ${code.name} failure is left to the offline banner',
            (tester) async {
          await pumpListener(tester);
          await emit(tester, _failure(error: ApiException(code: code)));
          expect(find.byType(SnackBar), findsNothing);
        });
      }

      testWidgets('any other failure is still announced', (tester) async {
        await pumpListener(tester);
        await emit(tester,
            _failure(error: ApiException(code: ApiErrorCode.serverUnavailable)));
        expect(find.byType(SnackBar), findsOneWidget);
      });

      testWidgets('back online, a network failure is announced again',
          (tester) async {
        connectivity.markOnline();
        await pumpListener(tester);
        await emit(tester, _failure(error: _offline));
        expect(find.byType(SnackBar), findsOneWidget);
      });
    });

    testWidgets('an unknown failure falls back to the generic reason',
        (tester) async {
      await pumpListener(tester);
      await emit(tester, _failure());
      expect(find.text(_staleMessage(l10n(english), null)), findsOneWidget);
    });

    testWidgets('a server message is shown in the snack', (tester) async {
      final error = ApiException(
        code: ApiErrorCode.validation,
        serverMessage: 'لا يمكن قراءة الزيارات الآن',
      );
      await pumpListener(tester, surface: phoneAr);
      await emit(tester, _failure(error: error));
      expect(find.text(_staleMessage(l10n(arabic), error)), findsOneWidget);
    });

    testWidgets('nothing on screen yet: silent (the error view owns it)',
        (tester) async {
      await pumpListener(tester);
      await emit(tester, VisitsListState(status: VisitsListStatus.loading));
      await emit(tester, _failure(items: const [], error: _offline));
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a failure repeated back to back is reported once',
        (tester) async {
      await pumpListener(tester);
      await emit(tester, _failure(error: _offline));
      expect(find.byType(SnackBar), findsOneWidget);

      // Dismiss it, then fail again without a success in between.
      ScaffoldMessenger.of(tester.element(find.byKey(const Key('child'))))
          .removeCurrentSnackBar();
      await tester.pump();
      await emit(
        tester,
        _failure(error: ApiException(code: ApiErrorCode.timeout)),
      );
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('fail → recover → fail reports each failure', (tester) async {
      await pumpListener(tester);
      await emit(tester, _failure(error: _offline));
      final messenger = ScaffoldMessenger.of(
          tester.element(find.byKey(const Key('child'))));
      messenger.removeCurrentSnackBar();
      await tester.pump();

      await emit(tester, _success());
      expect(find.byType(SnackBar), findsNothing);
      await emit(tester, _failure(error: _offline));
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('a loading refresh and a success are silent', (tester) async {
      await pumpListener(tester);
      await emit(tester,
          VisitsListState(status: VisitsListStatus.loading, items: _rows));
      await emit(tester, _success([..._rows, const Visit(id: 3)]));
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('quiet while its screen is kept offstage', (tester) async {
      await pumpListener(tester, visible: false);
      await emit(tester, _failure(error: _offline));
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('speaks again once its screen is shown', (tester) async {
      await pumpListener(tester, visible: false);
      await pumpListener(tester);
      await emit(tester, _failure(error: _offline));
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testOnEverySurface(
      'the snack with the longest reason fits',
      (s) => withBlocs(
        list: bloc,
        const VisitsRefreshFailureListener(child: SizedBox.expand()),
      ),
      verify: (tester, s) async {
        bloc.push(_failure(
          error: ApiException(
            code: ApiErrorCode.validation,
            serverMessage: LongText.of(s) * 3,
          ),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(SnackBar), findsOneWidget);
      },
    );
  });

  group('RefreshableEmptyView', () {
    testOnEverySurface(
      'fills the viewport with the empty message',
      (s) => RefreshableEmptyView(
        icon: Symbols.event_busy,
        message: LongText.of(s),
      ),
      verify: (tester, s) async {
        expect(find.text(LongText.of(s)), findsOneWidget);
        final view = tester.getSize(find.byType(RefreshableEmptyView));
        final filler = tester.getSize(find
            .descendant(
              of: find.byType(RefreshableEmptyView),
              matching: find.byType(SizedBox),
            )
            .first);
        expect(filler.height, view.height);
      },
    );

    testWidgets('shows the icon and always scrolls, even when it fits',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const RefreshableEmptyView(icon: Symbols.event_busy, message: 'None'),
      );
      expect(find.byType(EmptyView), findsOneWidget);
      expect(find.byIcon(Symbols.event_busy), findsOneWidget);
      final scroll = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView).first);
      expect(scroll.physics, isA<AlwaysScrollableScrollPhysics>());
    });

    testWidgets('can be pulled to refresh, once per pull', (tester) async {
      var refreshes = 0;
      final done = Completer<void>();
      await pumpSurface(
        tester,
        phoneAr,
        AppRefreshIndicator(
          onRefresh: () {
            refreshes++;
            return done.future;
          },
          child: RefreshableEmptyView(
            icon: Symbols.event_busy,
            message: l10n(arabic).dashboardActiveEmpty,
          ),
        ),
      );
      await tester.fling(
        find.byType(RefreshableEmptyView),
        const Offset(0, 400),
        1000,
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(refreshes, 1);
      expect(find.byType(RefreshProgressIndicator), findsOneWidget);

      done.complete();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(RefreshProgressIndicator), findsNothing);
      expect(refreshes, 1);
    });
  });
}
