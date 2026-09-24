import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/core/constants.dart';
import 'package:location_gps/features/visits/view/visit_detail_row.dart';
import 'package:location_gps/shared/widgets/widgets.dart';

import '../../widgets/widget_harness.dart';
import '../feature_fakes.dart';

const _longValue =
    'زيارة متابعة لمناقشة تفاصيل العقد والجدول الزمني للتسليم ومراجعة '
    'الملاحظات الفنية الواردة من فريق التنفيذ في الموقع الرئيسي للمشروع';

void main() {
  setUpAll(initHarness);

  group('VisitDetailRow layout', () {
    testOnEverySurface(
      'long label and value, with a maps pill, a chevron row and a plain row',
      (s) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            VisitDetailRow(
              icon: Icons.place_outlined,
              label: LongText.of(s),
              value: '$_longValue ${LongText.of(s)}',
              trailing:
                  const VisitMapsPill(latitude: 24.7136, longitude: 46.6753),
            ),
            VisitDetailRow(
              icon: Icons.storefront_outlined,
              label: l10n(s.locale).wfFieldCustomer,
              value: LongText.of(s),
              onTap: () {},
            ),
            VisitDetailRow(
              icon: Icons.flag_outlined,
              label: '',
              value: 'x' * 120,
            ),
          ],
        ),
      ),
      scrollable: true,
      verify: (tester, s) async {
        final label = tester.widget<Text>(find.text(LongText.of(s)).first);
        expect(label.maxLines, 1);
        expect(label.overflow, TextOverflow.ellipsis);
        final value =
            tester.widget<Text>(find.text('$_longValue ${LongText.of(s)}'));
        expect(value.maxLines, isNull, reason: 'the value wraps in full');
        expect(
          tester.getSize(find.text('$_longValue ${LongText.of(s)}')).height,
          greaterThan(40),
          reason: 'several lines, not one clipped line',
        );
      },
    );
  });

  group('VisitDetailRow behaviour', () {
    testWidgets('the badge takes the icon colour, or the primary',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const Column(
          children: [
            VisitDetailRow(
                key: Key('tinted'),
                icon: Icons.timelapse,
                label: 'L',
                value: 'V',
                iconColor: Colors.orange),
            VisitDetailRow(
                key: Key('plain'), icon: Icons.flag, label: 'L2', value: 'V2'),
          ],
        ),
      );
      IconBadge badge(String key) => tester.widget<IconBadge>(find.descendant(
          of: find.byKey(Key(key)), matching: find.byType(IconBadge)));
      expect(badge('tinted').color, Colors.orange);
      expect(badge('tinted').icon, Icons.timelapse);
      final cs = Theme.of(tester.element(find.byKey(const Key('plain'))))
          .colorScheme;
      expect(badge('plain').color, cs.primary);
      expect(tester.widget<Text>(find.text('L2')).style?.color,
          cs.onSurfaceVariant);
    });

    testWidgets('a value colour is applied; none by default', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const Column(children: [
          VisitDetailRow(
              icon: Icons.flag, label: 'A', value: 'warn', valueColor: Colors.red),
          VisitDetailRow(icon: Icons.flag, label: 'B', value: 'calm'),
        ]),
      );
      expect(tester.widget<Text>(find.text('warn')).style?.color, Colors.red);
      // Otherwise the theme's body ink.
      final context = tester.element(find.text('calm'));
      expect(tester.widget<Text>(find.text('calm')).style?.color,
          Theme.of(context).textTheme.bodyLarge?.color);
    });

    testWidgets('a plain row is not tappable and has no chevron',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const VisitDetailRow(icon: Icons.flag, label: 'A', value: 'B'),
      );
      expect(find.byType(InkWell), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.byIcon(Icons.chevron_left), findsNothing);
    });

    testWidgets('onTap makes the whole row tappable, once per tap',
        (tester) async {
      var taps = 0;
      await pumpSurface(
        tester,
        phoneEn,
        VisitDetailRow(
            icon: Icons.flag, label: 'Label', value: 'Value', onTap: () => taps++),
      );
      await tester.tap(find.text('Label'));
      await tester.pump();
      await tester.tap(find.byType(IconBadge));
      await tester.pump();
      expect(taps, 2);
      expect(tester.getSize(find.byType(InkWell)).height,
          greaterThanOrEqualTo(kMinInteractiveDimension));
    });

    for (final s in const [phoneEn, phoneAr]) {
      testWidgets('the chevron points forward — ${s.name}', (tester) async {
        await pumpSurface(
          tester,
          s,
          VisitDetailRow(
              icon: Icons.flag, label: 'Label', value: 'Value', onTap: () {}),
        );
        final chevron = tester.widget<Icon>(find.byType(Icon).last);
        final direction =
            Directionality.of(tester.element(find.byType(VisitDetailRow)));
        expect(chevronPointsToEnd(chevron.icon!, direction), isTrue);
        // And it sits at the end edge.
        final badge = tester.getCenter(find.byType(IconBadge)).dx;
        final end = tester.getCenter(find.byType(Icon).last).dx;
        expect(end > badge, s == phoneEn);
      });
    }

    testWidgets('a trailing widget replaces the chevron', (tester) async {
      var taps = 0;
      await pumpSurface(
        tester,
        phoneEn,
        VisitDetailRow(
          icon: Icons.flag,
          label: 'Label',
          value: 'Value',
          onTap: () => taps++,
          trailing: const Text('trail'),
        ),
      );
      expect(find.text('trail'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      await tester.tap(find.text('Value'));
      await tester.pump();
      expect(taps, 1, reason: 'the row stays tappable');
    });

    testWidgets('an empty value still lays out', (tester) async {
      await pumpSurface(
        tester,
        surfaces[0],
        const VisitDetailRow(icon: Icons.flag, label: '', value: ''),
      );
      expectCleanLayout(tester);
    });
  });

  group('VisitMapsPill', () {
    Future<void> pumpPill(WidgetTester tester, Surface s, {String? label}) =>
        pumpSurface(
          tester,
          s,
          Center(
            child: VisitMapsPill(
              latitude: 24.7136,
              longitude: 46.6753,
              label: label,
            ),
          ),
        );

    testOnEverySurface(
      'is a full tap target, named for screen readers',
      (s) => const Center(
        child: VisitMapsPill(latitude: 24.7136, longitude: 46.6753),
      ),
      verify: (tester, s) async {
        final size = tester.getSize(find.byType(InkWell));
        expect(size.width, greaterThanOrEqualTo(kMinInteractiveDimension));
        expect(size.height, greaterThanOrEqualTo(kMinInteractiveDimension));
        expect(find.byTooltip(l10n(s.locale).wfOpenInMaps), findsOneWidget);
        final badge = tester.widget<IconBadge>(find.byType(IconBadge));
        expect(badge.color,
            Theme.of(tester.element(find.byType(IconBadge))).colorScheme.tertiary);
      },
    );

    testWidgets('a tap opens the maps app at the point, with its label',
        (tester) async {
      final launched = mockUrlLauncher();
      await pumpPill(tester, phoneEn, label: 'Olaya St');
      await tester.tap(find.byType(VisitMapsPill));
      await tester.pump();
      await tester.pump();
      expect(launched, hasLength(1));
      final uri = Uri.parse(launched.single);
      expect(uri.scheme, 'geo');
      expect(uri.path, '24.7136,46.6753');
      expect(uri.queryParameters['q'], '24.7136,46.6753(Olaya St)');
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('without a maps app it falls back to the web',
        (tester) async {
      final launched = mockUrlLauncher(canLaunch: false);
      await pumpPill(tester, phoneEn);
      await tester.tap(find.byType(VisitMapsPill));
      await tester.pump();
      await tester.pump();
      expect(launched.single,
          '${AppConstants.googleMapsSearchUrl}24.7136,46.6753');
    });

    testWidgets('a failed launch says so, in the UI language',
        (tester) async {
      mockUrlLauncher(launches: false);
      await pumpPill(tester, phoneAr);
      await tester.tap(find.byType(VisitMapsPill));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(l10n(arabic).errCannotLaunchApp), findsOneWidget);
    });

    testWidgets('a launcher that throws is a failure, not a crash',
        (tester) async {
      mockUrlLauncher(error: PlatformException(code: 'ACTIVITY_NOT_FOUND'));
      await pumpPill(tester, phoneEn);
      await tester.tap(find.byType(VisitMapsPill));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(l10n(english).errCannotLaunchApp), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
