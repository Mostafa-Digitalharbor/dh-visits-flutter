import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/core/constants.dart';
import 'package:location_gps/core/di/service_locator.dart';
import 'package:location_gps/core/utils/app_number.dart';
import 'package:location_gps/core/utils/distance.dart';
import 'package:location_gps/features/visits/data/models/visit.dart';
import 'package:location_gps/features/visits/data/models/visit_location_log.dart';
import 'package:location_gps/features/visits/data/visits_repository.dart';
import 'package:location_gps/features/visits/view/visit_labels.dart';
import 'package:location_gps/features/visits/view/visit_map_card.dart';
import 'package:location_gps/shared/widgets/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../widgets/widget_harness.dart';
import '../feature_fakes.dart';

/// The customer's planned spot.
const _office = LatLng(24.7136, 46.6753);

/// ~45 m from the office: in range.
const _near = LatLng(24.7140, 46.6753);

/// ~1.1 km away: out of range.
const _far = LatLng(24.7236, 46.6753);

Visit _visit({
  LatLng? planned = _office,
  LatLng? checkIn = _near,
  LatLng? checkOut = _far,
  int? partnerId,
  String? location = 'طريق الملك عبد العزيز، حي الملقا، الرياض',
  VisitState state = VisitState.done,
}) =>
    Visit(
      id: 5,
      partnerId: partnerId,
      partnerName: 'Acme',
      latitude: planned?.latitude,
      longitude: planned?.longitude,
      startLat: checkIn?.latitude,
      startLng: checkIn?.longitude,
      endLat: checkOut?.latitude,
      endLng: checkOut?.longitude,
      startLocation: 'Olaya St',
      location: location,
      state: state,
    );

String _verdict(WidgetTester tester, {required bool start}) {
  final t = l10n(english);
  final label = t.wfLabelColon(start ? t.wfStartedLabel : t.wfEndedLabel);
  final rich = tester
      .widgetList<Text>(find.byType(Text))
      .where((w) => w.textSpan != null)
      .map((w) => w.textSpan!.toPlainText())
      .firstWhere((text) => text.startsWith(label));
  return rich.substring(label.length).trim();
}

List<MapPin> _pins(WidgetTester tester) =>
    tester.widgetList<MapPin>(find.byType(MapPin)).toList();

void main() {
  setUpAll(initHarness);

  late FakeVisitsRepo repo;
  setUp(() {
    repo = FakeVisitsRepo();
    sl.registerSingleton<VisitsRepository>(repo);
  });
  tearDown(() => sl.reset());

  Future<void> pumpCard(
    WidgetTester tester,
    Visit visit, {
    VisitTrack? trail,
    VoidCallback? onOpenTrail,
    Surface surface = phoneEn,
  }) =>
      pumpSurface(
        tester,
        surface,
        VisitMapCard(
          key: UniqueKey(),
          visit: visit,
          trail: trail,
          onOpenTrail: onOpenTrail,
        ),
        scrollable: true,
      );

  group('layout', () {
    testMapOnEverySurface(
      'office, both check points, a trail and a long address',
      (s) => Padding(
        padding: const EdgeInsets.all(16),
        child: VisitMapCard(
          visit: _visit(location: '${LongText.of(s)} ${LongText.of(s)}'),
          trail: trackOf(5, 6),
          onOpenTrail: () {},
        ),
      ),
      scrollable: true,
      verify: (tester, s) async {
        expect(find.byType(AppMap), findsOneWidget);
        expect(find.bySemanticsLabel(l10n(s.locale).trailOpenFull),
            findsOneWidget);
        expect(find.bySemanticsLabel(l10n(s.locale).mapOpenDirections),
            findsOneWidget);
        final height = tester.getSize(find.byType(AppMap)).height;
        final fixed = CompSz.mapCard *
            (s.textScale.clamp(1.0, Responsive.maxTextScale));
        expect(height,
            moreOrLessEquals(fixed < s.size.height / 2 ? fixed : s.size.height / 2));
      },
    );
  });

  group('when there is nothing to plot', () {
    testWidgets('no coordinates and no trail: no card at all',
        (tester) async {
      await pumpCard(
          tester, _visit(planned: null, checkIn: null, checkOut: null));
      expect(find.byType(Card), findsNothing);
      expect(find.byType(AppMap), findsNothing);
    });

    testWidgets('a 0,0 planned point is no point', (tester) async {
      await pumpCard(
        tester,
        _visit(planned: const LatLng(0, 0), checkIn: null, checkOut: null),
      );
      expect(find.byType(Card), findsNothing);
    });

    testMapWidgets('a trail alone is enough', (tester) async {
      await pumpCard(
        tester,
        _visit(planned: null, checkIn: null, checkOut: null, location: null),
        trail: trackOf(5, 3),
      );
      expect(find.byType(AppMap), findsOneWidget);
      // No customer: no fence, no verdicts, no address.
      expect(find.byType(CircleLayer), findsNothing);
      expect(find.byIcon(Icons.verified_outlined), findsNothing);
      expect(find.byIcon(Icons.place_outlined), findsNothing);
    });
  });

  group('the customer', () {
    testMapWidgets('the planned point draws the fence and the office pin',
        (tester) async {
      await pumpCard(tester, _visit(checkIn: null, checkOut: null));
      final circles = tester
          .widgetList<CircleLayer>(find.byType(CircleLayer))
          .expand((l) => l.circles)
          .toList();
      expect(circles, hasLength(2), reason: 'the fence and its pulse');
      for (final c in circles) {
        expect(c.point, _office);
        expect(c.useRadiusInMeter, isTrue);
        expect(c.radius, greaterThanOrEqualTo(AppConstants.checkInRangeMeters));
      }
      final context = tester.element(find.byType(VisitMapCard));
      final pin = _pins(tester).single;
      expect(pin.color, Theme.of(context).colorScheme.primary);
      expect((pin.child as Icon).icon, Symbols.business);
    });

    testMapWidgets('the fence pulse keeps beating without a hot loop',
        (tester) async {
      await pumpCard(tester, _visit());
      expect(find.byType(AmbientPulse), findsWidgets);
      await pumpFrames(tester, const Duration(seconds: 7));
      expectCleanLayout(tester);
    });

    testMapWidgets('the customer record\'s coordinates win, read once',
        (tester) async {
      repo.partner = const PartnerLocation(
        latitude: 24.80,
        longitude: 46.70,
        address: 'Partner HQ, King Fahd Rd',
      );
      await pumpCard(tester, _visit(partnerId: 77));
      await tester.pump();
      expect(repo.partnerLocationCalls, 1);
      final circle = tester.widget<CircleLayer>(find.byType(CircleLayer).last);
      expect(circle.circles.single.point, const LatLng(24.80, 46.70));
      expect(find.text('Partner HQ, King Fahd Rd'), findsOneWidget);
      expect(find.textContaining('طريق الملك'), findsNothing);
      // The check-in is now far from the (moved) office.
      expect(_verdict(tester, start: true),
          startsWith(l10n(english).visitDetailOutRange));

      // A rebuild does not read it again.
      await tester.pump(const Duration(seconds: 1));
      expect(repo.partnerLocationCalls, 1);
    });

    testMapWidgets('no customer record falls back to the planned point',
        (tester) async {
      await pumpCard(tester, _visit(partnerId: 77));
      await tester.pump();
      expect(repo.partnerLocationCalls, 1);
      final circle = tester.widget<CircleLayer>(find.byType(CircleLayer).last);
      expect(circle.circles.single.point, _office);
    });

    testMapWidgets('a customer read landing after the card is gone is ignored',
        (tester) async {
      final gate = Completer<PartnerLocation?>();
      final slowRepo = _SlowPartnerRepo(gate.future);
      await sl.reset();
      sl.registerSingleton<VisitsRepository>(slowRepo);
      await pumpCard(tester, _visit(partnerId: 77));
      await tester.pumpWidget(const SizedBox());
      gate.complete(const PartnerLocation(latitude: 1, longitude: 1));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('check-in and check-out', () {
    testMapWidgets('pins mark both, green in and orange out', (tester) async {
      await pumpCard(tester, _visit());
      final colors = _pins(tester).map((p) => p.color).toList();
      expect(colors, contains(AppColors.routeStart));
      expect(colors, contains(AppColors.routeEnd));
      final icons = _pins(tester).map((p) => (p.child as Icon).icon).toList();
      expect(icons, containsAll([Symbols.login, Symbols.logout]));
    });

    testMapWidgets('a drawn trail replaces the two pins it would duplicate',
        (tester) async {
      await pumpCard(tester, _visit(), trail: trackOf(5, 4));
      final icons = _pins(tester)
          .where((p) => p.child is Icon)
          .map((p) => (p.child as Icon).icon)
          .toList();
      expect(icons, isNot(contains(Symbols.login)));
      expect(icons, isNot(contains(Symbols.logout)));
      expect(icons, contains(Symbols.business));
    });

    testMapWidgets('a single-fix trail keeps the pins', (tester) async {
      await pumpCard(tester, _visit(), trail: trackOf(5, 1));
      final icons = _pins(tester)
          .where((p) => p.child is Icon)
          .map((p) => (p.child as Icon).icon)
          .toList();
      expect(icons, containsAll([Symbols.login, Symbols.logout]));
    });

    testMapWidgets('in range and out of range, with distance and radius',
        (tester) async {
      await pumpCard(tester, _visit());
      final t = l10n(english);
      final sep = t.commonListSeparator;
      final radius = t.wfRangeRadius(
          AppNumber.distance(t, AppConstants.checkInRangeMeters));
      final nearM = haversineMeters(_office.latitude, _office.longitude,
          _near.latitude, _near.longitude);
      final farM = haversineMeters(_office.latitude, _office.longitude,
          _far.latitude, _far.longitude);
      expect(_verdict(tester, start: true),
          '${t.visitDetailInRange}$sep${t.wfRangeDistance(AppNumber.distance(t, nearM))}$sep$radius');
      expect(_verdict(tester, start: false),
          '${t.visitDetailOutRange}$sep${t.wfRangeDistance(AppNumber.distance(t, farM))}$sep$radius');

      final context = tester.element(find.byType(VisitMapCard));
      expect(tester.widget<Icon>(find.byIcon(Icons.verified_outlined)).color,
          context.visitSuccess);
      expect(tester.widget<Icon>(find.byIcon(Icons.error_outline)).color,
          Theme.of(context).colorScheme.error);
    });

    testMapWidgets('exactly on the fence counts as in range', (tester) async {
      // 200 m due north of the office, give or take rounding.
      const onFence = LatLng(24.7136 + 200 / 111195, 46.6753);
      await pumpCard(tester, _visit(checkIn: onFence, checkOut: null));
      final meters = haversineMeters(_office.latitude, _office.longitude,
          onFence.latitude, onFence.longitude);
      final t = l10n(english);
      expect(
        _verdict(tester, start: true).startsWith(t.visitDetailInRange),
        meters <= AppConstants.checkInRangeMeters,
      );
    });

    testMapWidgets('no address and no verdicts: no footer', (tester) async {
      await pumpCard(
        tester,
        _visit(checkIn: null, checkOut: null, location: ''),
      );
      expect(find.byIcon(Icons.place_outlined), findsNothing);
      expect(find.byIcon(Icons.verified_outlined), findsNothing);
    });

    testMapWidgets('the verdict text scales with the user font', (tester) async {
      await pumpCard(tester, _visit(), surface: surfaces[1]);
      final verdicts = tester
          .widgetList<Text>(find.byType(Text))
          .where((w) => w.textSpan != null);
      expect(verdicts, hasLength(2),
          reason: 'Text.rich (text-scaled), never RichText');
      expect(find.byType(RichText), findsWidgets);
      expectCleanLayout(tester);
    });

    testMapWidgets('tapping a check pin opens it in maps', (tester) async {
      final launched = mockUrlLauncher();
      await pumpCard(tester, _visit(checkOut: null));
      final pin = find.ancestor(
        of: find.byIcon(Symbols.login),
        matching: find.byType(GestureDetector),
      );
      await tester.tap(pin.first);
      await tester.pump();
      await tester.pump();
      expect(launched, hasLength(1));
      final uri = Uri.parse(launched.single);
      expect(uri.path, '${_near.latitude},${_near.longitude}');
      expect(uri.queryParameters['q'], contains('Olaya St'));
    });
  });

  group('map buttons', () {
    testMapWidgets('directions head for the customer, named for readers',
        (tester) async {
      final launched = mockUrlLauncher();
      await pumpCard(tester, _visit(), surface: phoneAr);
      final directions =
          find.bySemanticsLabel(l10n(arabic).mapOpenDirections);
      expect(directions, findsOneWidget);
      await tester.tap(find.byIcon(Symbols.assistant_direction));
      await tester.pump();
      await tester.pump();
      final uri = Uri.parse(launched.single);
      expect(uri.path, '${_office.latitude},${_office.longitude}');
      expect(uri.queryParameters['q'], contains('Acme'));
    });

    testMapWidgets('without a customer, directions head for the check-in',
        (tester) async {
      final launched = mockUrlLauncher();
      await pumpCard(tester, _visit(planned: null));
      await tester.tap(find.byIcon(Symbols.assistant_direction));
      await tester.pump();
      await tester.pump();
      expect(Uri.parse(launched.single).path,
          '${_near.latitude},${_near.longitude}');
    });

    testMapWidgets('a failed hand-off says so', (tester) async {
      mockUrlLauncher(launches: false);
      await pumpCard(tester, _visit());
      await tester.tap(find.byIcon(Symbols.assistant_direction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(l10n(english).errCannotLaunchApp), findsOneWidget);
    });

    testMapWidgets('the full-trail button needs a path and a handler',
        (tester) async {
      var opens = 0;
      final label = l10n(english).trailOpenFull;

      await pumpCard(tester, _visit(), trail: trackOf(5, 3));
      expect(find.bySemanticsLabel(label), findsNothing, reason: 'no handler');

      await pumpCard(tester, _visit(),
          trail: trackOf(5, 1), onOpenTrail: () => opens++);
      expect(find.bySemanticsLabel(label), findsNothing, reason: 'no path');

      await pumpCard(tester, _visit(),
          trail: trackOf(5, 3), onOpenTrail: () => opens++);
      expect(find.bySemanticsLabel(label), findsOneWidget);
      await tester.tap(find.byIcon(Symbols.timeline));
      await tester.pump();
      expect(opens, 1);
    });

    testMapWidgets('buttons sit at the end, the credit at the start',
        (tester) async {
      for (final (s, credit) in [
        (phoneEn, Alignment.bottomLeft),
        (phoneAr, Alignment.bottomRight),
      ]) {
        await pumpCard(tester, _visit(), surface: s);
        final map = tester.getRect(find.byType(AppMap));
        final fab = tester.getCenter(find.byType(MapFab));
        expect(fab.dx > map.center.dx, s == phoneEn, reason: s.name);
        expect(tester.widget<AppMap>(find.byType(AppMap)).attributionAlignment,
            credit);
      }
    });

    testMapWidgets('a live visit draws a live trail end', (tester) async {
      await pumpCard(
        tester,
        _visit(state: VisitState.inProgress),
        trail: trackOf(5, 3),
      );
      // The live end pulses; a finished trail's end does not.
      final live = find.byType(AmbientPulse).evaluate().length;
      await pumpCard(tester, _visit(), trail: trackOf(5, 3));
      final finished = find.byType(AmbientPulse).evaluate().length;
      expect(live, greaterThan(finished));
    });
  });

  group('camera', () {
    testMapWidgets('the trail arriving later rebuilds the map once to fit it',
        (tester) async {
      final visit = _visit();
      await pumpSurface(tester, phoneEn,
          VisitMapCard(visit: visit, trail: null), scrollable: true);
      final first = tester.widget<AppMap>(find.byType(AppMap)).key;

      await pumpSurface(tester, phoneEn,
          VisitMapCard(visit: visit, trail: trackOf(5, 3)), scrollable: true);
      final withPath = tester.widget<AppMap>(find.byType(AppMap));
      expect(withPath.key, isNot(first));
      // The fit covers the trail's vertices too.
      final fit = withPath.initialCameraFit! as FitBounds;
      for (final p in latLngs(trackOf(5, 3).logs)) {
        expect(fit.bounds.contains(p), isTrue);
      }

      // A poll adding points keeps the same map (and the user's camera).
      await pumpSurface(tester, phoneEn,
          VisitMapCard(visit: visit, trail: trackOf(5, 6)), scrollable: true);
      expect(tester.widget<AppMap>(find.byType(AppMap)).key, withPath.key);
    });

    testMapWidgets('a lone point opens centred instead of fitted',
        (tester) async {
      await pumpCard(tester, _visit(checkIn: null, checkOut: null));
      final map = tester.widget<AppMap>(find.byType(AppMap));
      expect(map.initialCameraFit, isNull);
      expect(map.initialCenter, _office);
      expect(map.initialZoom, AppConstants.mapZoomVisitDetail);
    });
  });
}

class _SlowPartnerRepo extends FakeVisitsRepo {
  _SlowPartnerRepo(this.answer);
  final Future<PartnerLocation?> answer;

  @override
  Future<PartnerLocation?> partnerLocation(int partnerId) => answer;
}
