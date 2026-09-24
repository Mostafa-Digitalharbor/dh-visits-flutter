import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/features/dashboard/view/dashboard_active_map_card.dart';
import 'package:location_gps/features/visits/data/models/visit.dart';
import 'package:location_gps/shared/widgets/widgets.dart';

import '../../widgets/widget_harness.dart';
import '../feature_fakes.dart';

/// A running visit checked in at a spot [i] steps from central Riyadh.
Visit _active(
  int i, {
  String? employee = LongText.arabicPerson,
  String? customer = LongText.arabicCompany,
  bool located = true,
  VisitState state = VisitState.inProgress,
}) =>
    Visit(
      id: 100 + i,
      name: 'VIS/2026/${100 + i}',
      employeeName: employee,
      partnerName: customer,
      state: state,
      startDatetime: fixtureDay,
      startLat: located ? 24.70 + i * 0.01 : null,
      startLng: located ? 46.67 + i * 0.01 : null,
    );

List<Visit> _many(int n) => [for (var i = 0; i < n; i++) _active(i)];

void main() {
  setUpAll(initHarness);

  group('DashboardActiveMapCard layout', () {
    testMapOnEverySurface(
      'five running visits with long names: map, three rows and "+2 more"',
      (s) => Padding(
        padding: const EdgeInsets.all(16),
        child: DashboardActiveMapCard(visits: _many(5)),
      ),
      scrollable: true,
      verify: (tester, s) async {
        final t = l10n(s.locale);
        expect(find.byType(AppMap), findsOneWidget);
        expect(find.byType(ListTile), findsNWidgets(3));
        expect(find.text(t.dashboardActiveMore(2)), findsOneWidget);
        expect(find.text(t.dashboardActiveOnMapTitle), findsOneWidget);
        final title = tester.widget<Text>(find
            .descendant(
                of: find.byType(ListTile).first,
                matching: find.text(LongText.arabicPerson))
            .first);
        expect(title.maxLines, 1);
        expect(title.overflow, TextOverflow.ellipsis);
      },
    );

    testOnEverySurface(
      'nobody checked in: the empty row, no map, no badge',
      (s) => Padding(
        padding: const EdgeInsets.all(16),
        child: DashboardActiveMapCard(visits: [
          _active(0, located: false),
          _active(1, state: VisitState.done),
        ]),
      ),
      verify: (tester, s) async {
        final t = l10n(s.locale);
        expect(find.text(t.dashboardActiveEmpty), findsOneWidget);
        expect(find.byType(InlineEmptyRow), findsOneWidget);
        expect(find.byType(AppMap), findsNothing);
        expect(find.byType(TonePill), findsNothing);
      },
    );
  });

  group('DashboardActiveMapCard behaviour', () {
    testMapWidgets('only running visits with a position count', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        DashboardActiveMapCard(visits: [
          _active(0, employee: 'Sam'),
          _active(1, employee: 'No fix', located: false),
          _active(2, employee: 'Finished', state: VisitState.done),
          _active(3, employee: 'Approved', state: VisitState.approved),
          _active(4, employee: 'Lina'),
        ]),
        scrollable: true,
      );
      expect(find.byType(ListTile), findsNWidgets(2));
      expect(find.text('Sam'), findsOneWidget);
      expect(find.text('Lina'), findsOneWidget);
      expect(find.text('No fix'), findsNothing);
      expect(find.text('Finished'), findsNothing);
      // Pins, rows and the badge agree.
      expect(find.byType(MapPin), findsNWidgets(2));
      final badge = tester.widget<TonePill>(find.byType(TonePill));
      expect(badge.label, '2');
      final context = tester.element(find.byType(DashboardActiveMapCard));
      expect(badge.color, context.x.success);
    });

    testMapWidgets('exactly three rows get no "+more" line', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        DashboardActiveMapCard(visits: _many(3)),
        scrollable: true,
      );
      expect(find.byType(ListTile), findsNWidgets(3));
      expect(find.textContaining('+'), findsNothing);
      expect(find.text(l10n(english).dashboardActiveMore(0)), findsNothing);
    });

    testMapWidgets('a large team counts every pin, lists three', (tester) async {
      await pumpSurface(
        tester,
        phoneAr,
        DashboardActiveMapCard(visits: _many(1200)),
        scrollable: true,
      );
      expect(find.byType(ListTile), findsNWidgets(3));
      expect(find.text(l10n(arabic).dashboardActiveMore(1197)), findsOneWidget);
      expect(tester.widget<TonePill>(find.byType(TonePill)).label, '1,200');
      expectCleanLayout(tester);
    });

    testMapWidgets('missing names read as "no value"', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        DashboardActiveMapCard(
            visits: [_active(0, employee: null, customer: null)]),
        scrollable: true,
      );
      final none = l10n(english).commonNoValue;
      expect(
        find.descendant(of: find.byType(ListTile), matching: find.text(none)),
        findsNWidgets(2),
      );
      expectCleanLayout(tester);
    });

    testMapWidgets('pins use the fixed map hue and name the employee',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        DashboardActiveMapCard(visits: [_active(0, employee: 'Sam Sales')]),
        scrollable: true,
      );
      final pin = tester.widget<MapPin>(find.byType(MapPin));
      expect(pin.color, AppColors.green);
      expect(pin.tooltip, 'Sam Sales');
      expect(find.byTooltip('Sam Sales'), findsOneWidget);
      // A static preview: the page scrolls instead of the map panning.
      expect(tester.widget<AppMap>(find.byType(AppMap)).interactive, isFalse);
    });

    testMapWidgets('one employee gets no camera fit (no infinite zoom)',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        DashboardActiveMapCard(visits: [_active(0)]),
        scrollable: true,
      );
      expect(tester.widget<AppMap>(find.byType(AppMap)).initialCameraFit,
          isNull);
      expectCleanLayout(tester);
    });

    testMapWidgets('tapping a row opens that visit, once', (tester) async {
      final visits = [
        _active(0, employee: 'Sam'),
        _active(1, employee: 'Lina'),
      ];
      final log = await pumpRouted(
        tester,
        phoneEn,
        SingleChildScrollView(child: DashboardActiveMapCard(visits: visits)),
      );
      await tester.tap(find.text('Lina'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(log.locations, ['/visits/101']);
      expect(log.extras.single, visits[1]);
    });

    testMapWidgets('tapping a pin opens that visit', (tester) async {
      final visits = [_active(0, employee: 'Sam')];
      final log = await pumpRouted(
        tester,
        phoneEn,
        SingleChildScrollView(child: DashboardActiveMapCard(visits: visits)),
      );
      await tester.tap(find.byType(MapPin));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(log.locations, ['/visits/100']);
      expect(log.extras.single, visits.single);
    });

    testMapWidgets('rows are comfortable tap targets with a mirrored chevron',
        (tester) async {
      for (final s in const [phoneEn, phoneAr]) {
        await pumpSurface(
          tester,
          s,
          DashboardActiveMapCard(visits: [_active(0)]),
          scrollable: true,
        );
        expect(tester.getSize(find.byType(ListTile)).height,
            greaterThanOrEqualTo(kMinInteractiveDimension));
        final chevron = tester.widget<Icon>(find.byIcon(Icons.chevron_right));
        final dir = Directionality.of(tester.element(find.byType(ListTile)));
        expect(chevronPointsToEnd(chevron.icon!, dir), isTrue);
      }
    });

    testMapWidgets('the row avatar uses the success container pair',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        DashboardActiveMapCard(visits: [_active(0)]),
        scrollable: true,
      );
      final avatar = tester.widget<InitialAvatar>(find.byType(InitialAvatar));
      final x = tester.element(find.byType(InitialAvatar)).x;
      expect(avatar.background, x.successContainer);
      expect(avatar.foreground, x.onSuccessContainer);
    });
  });
}
